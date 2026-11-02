import {
  fromBase64,
  openTeamKey,
  randomBytes,
  safeEqual,
  sealTeamKey,
  sha256Hex,
  toBase64,
  toBase64Url,
} from './crypto';

export { TeamSync } from './team_sync';

declare global {
  interface Env {
    DB: D1Database;
    TEAM: DurableObjectNamespace;
    /** 商品图片、收款码图片（设备加密后的密文）。 */
    MEDIA: R2Bucket;
    EMAIL_MODE: 'log' | 'resend';
    EMAIL_FROM: string;
    KEY_WRAP_SECRET: string;
    RESEND_API_KEY?: string;
    /** 仅开发环境：以此结尾的邮箱直接返回验证码。 */
    DEV_CODE_SUFFIX?: string;
  }
}

const CODE_TTL_MS = 10 * 60 * 1000;
const SESSION_TTL_MS = 180 * 24 * 60 * 60 * 1000;
const MAX_CODE_ATTEMPTS = 5;
const MAX_CODES_PER_DAY = 10;
const RESEND_INTERVAL_MS = 60 * 1000;
/** 单张图片密文的上限（设备端限制原图 8 MB，加密只多几十字节）。 */
const MAX_MEDIA_BYTES = 8 * 1024 * 1024 + 1024;

class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await route(request, env);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code }, e.status);
      console.error(e);
      return json({ error: 'internal' }, 500);
    }
  },
} satisfies ExportedHandler<Env>;

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;

  if (path === '/health') return json({ ok: true });
  if (path === '/auth/start' && method === 'POST') return startLogin(request, env);
  if (path === '/auth/verify' && method === 'POST') return verifyLogin(request, env);
  if (path === '/auth/logout' && method === 'POST') return logout(request, env);
  if (path === '/me' && method === 'GET') return getProfile(request, env);
  if (path === '/me' && method === 'PUT') return updateProfile(request, env);
  if (path === '/teams' && method === 'GET') return listTeams(request, env);

  const team = path.match(/^\/teams\/([0-9a-f-]{36})\/(link|key|sync)$/);
  if (team) {
    const [, teamId, action] = team;
    if (action === 'link' && method === 'POST') return linkTeam(request, env, teamId);
    if (action === 'key' && method === 'GET') return teamKey(request, env, teamId);
    if (action === 'sync' && method === 'GET') return openSync(request, env, teamId);
  }
  // 文件名由设备生成（UUID + 扩展名），同名文件内容不会变。
  const media = path.match(/^\/teams\/([0-9a-f-]{36})\/media\/([0-9A-Za-z-]{1,64}\.[a-z0-9]{1,5})$/);
  if (media) {
    const [, teamId, name] = media;
    if (method === 'GET') return getMedia(request, env, teamId, name);
    if (method === 'PUT') return putMedia(request, env, teamId, name);
  }
  throw new HttpError(404, 'not_found');
}

// ---------- 邮箱验证码登录 ----------

function normalizeEmail(value: unknown): string {
  const email = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new HttpError(400, 'invalid_email');
  }
  return email;
}

async function readJson(request: Request): Promise<Record<string, unknown>> {
  try {
    return (await request.json()) as Record<string, unknown>;
  } catch {
    throw new HttpError(400, 'invalid_json');
  }
}

async function codeHash(env: Env, email: string, code: string): Promise<string> {
  return sha256Hex(`${env.KEY_WRAP_SECRET}:${email}:${code}`);
}

async function startLogin(request: Request, env: Env): Promise<Response> {
  const email = normalizeEmail((await readJson(request)).email);
  const now = Date.now();
  const day = new Date(now).toISOString().slice(0, 10);
  const existing = await env.DB.prepare('SELECT sent_at, day, sent_today FROM login_codes WHERE email = ?')
    .bind(email)
    .first<{ sent_at: number; day: string; sent_today: number }>();
  if (existing && now - existing.sent_at < RESEND_INTERVAL_MS) throw new HttpError(429, 'too_soon');
  const sentToday = existing && existing.day === day ? existing.sent_today : 0;
  if (sentToday >= MAX_CODES_PER_DAY) throw new HttpError(429, 'too_many_today');

  const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, '0');
  await env.DB.prepare(
    `INSERT INTO login_codes (email, code_hash, expires_at, attempts, sent_at, day, sent_today)
     VALUES (?, ?, ?, 0, ?, ?, ?)
     ON CONFLICT(email) DO UPDATE SET code_hash = excluded.code_hash, expires_at = excluded.expires_at,
       attempts = 0, sent_at = excluded.sent_at, day = excluded.day, sent_today = excluded.sent_today`,
  )
    .bind(email, await codeHash(env, email, code), now + CODE_TTL_MS, now, day, sentToday + 1)
    .run();

  const devCode = env.DEV_CODE_SUFFIX && email.endsWith(env.DEV_CODE_SUFFIX);
  if (env.EMAIL_MODE === 'resend' && !devCode) {
    try {
      await sendEmail(env, email, code);
    } catch (e) {
      // 没发出去就不算一次，否则用户 1 分钟内无法重试。
      await env.DB.prepare('DELETE FROM login_codes WHERE email = ?').bind(email).run();
      throw e;
    }
    return json({ ok: true });
  }
  // 本地开发，或开发环境里的测试邮箱：不发邮件，直接把验证码返回，方便模拟器和自动测试。
  console.log(`login code for ${email}: ${code}`);
  return json({ ok: true, devCode: code });
}

async function sendEmail(env: Env, to: string, code: string): Promise<void> {
  if (!env.RESEND_API_KEY) throw new HttpError(500, 'email_not_configured');
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: env.EMAIL_FROM,
      to,
      subject: `小算盘登录验证码 ${code}`,
      text: `你的验证码是 ${code}，10 分钟内有效。\n如果不是你本人操作，请忽略这封邮件。`,
    }),
  });
  if (!response.ok) {
    console.error('resend failed', response.status, await response.text());
    throw new HttpError(502, 'email_failed');
  }
}

async function verifyLogin(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const email = normalizeEmail(body.email);
  const code = typeof body.code === 'string' ? body.code.trim() : '';
  const row = await env.DB.prepare('SELECT code_hash, expires_at, attempts FROM login_codes WHERE email = ?')
    .bind(email)
    .first<{ code_hash: string; expires_at: number; attempts: number }>();
  if (!row || row.expires_at < Date.now()) throw new HttpError(400, 'code_expired');
  if (row.attempts >= MAX_CODE_ATTEMPTS) throw new HttpError(429, 'too_many_attempts');
  if (!safeEqual(row.code_hash, await codeHash(env, email, code))) {
    await env.DB.prepare('UPDATE login_codes SET attempts = attempts + 1 WHERE email = ?').bind(email).run();
    throw new HttpError(400, 'wrong_code');
  }
  await env.DB.prepare('DELETE FROM login_codes WHERE email = ?').bind(email).run();

  const now = Date.now();
  let account = await env.DB.prepare('SELECT id, display_name FROM accounts WHERE email = ?')
    .bind(email)
    .first<{ id: string; display_name: string | null }>();
  if (!account) {
    account = { id: crypto.randomUUID(), display_name: null };
    await env.DB.prepare('INSERT INTO accounts (id, email, created_at) VALUES (?, ?, ?)')
      .bind(account.id, email, now)
      .run();
  }
  const token = toBase64Url(randomBytes(32));
  await env.DB.prepare('INSERT INTO sessions (token_hash, account_id, created_at, expires_at) VALUES (?, ?, ?, ?)')
    .bind(await sha256Hex(token), account.id, now, now + SESSION_TTL_MS)
    .run();
  return json({ token, email, displayName: account.display_name });
}

async function requireAccount(request: Request, env: Env): Promise<string> {
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) throw new HttpError(401, 'unauthorized');
  const session = await env.DB.prepare('SELECT account_id, expires_at FROM sessions WHERE token_hash = ?')
    .bind(await sha256Hex(token))
    .first<{ account_id: string; expires_at: number }>();
  if (!session || session.expires_at < Date.now()) throw new HttpError(401, 'unauthorized');
  return session.account_id;
}

async function logout(request: Request, env: Env): Promise<Response> {
  const header = request.headers.get('Authorization') ?? '';
  if (header.startsWith('Bearer ')) {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(await sha256Hex(header.slice(7))).run();
  }
  return json({ ok: true });
}

// ---------- 用户名（显示名） ----------

const MAX_DISPLAY_NAME = 30;

async function getProfile(request: Request, env: Env): Promise<Response> {
  const accountId = await requireAccount(request, env);
  const row = await env.DB.prepare('SELECT email, display_name FROM accounts WHERE id = ?')
    .bind(accountId)
    .first<{ email: string; display_name: string | null }>();
  if (!row) throw new HttpError(401, 'unauthorized');
  return json({ email: row.email, displayName: row.display_name });
}

async function updateProfile(request: Request, env: Env): Promise<Response> {
  const accountId = await requireAccount(request, env);
  const value = (await readJson(request)).displayName;
  if (value !== null && typeof value !== 'string') throw new HttpError(400, 'invalid_name');
  // 去掉首尾空白和控制字符；空字符串表示清除。
  const name = typeof value === 'string' ? value.replace(/[\u0000-\u001f\u007f]/g, '').trim() : '';
  if ([...name].length > MAX_DISPLAY_NAME) throw new HttpError(400, 'invalid_name');
  await env.DB.prepare('UPDATE accounts SET display_name = ? WHERE id = ?')
    .bind(name || null, accountId)
    .run();
  return json({ displayName: name || null });
}

// ---------- 团队 ----------

async function listTeams(request: Request, env: Env): Promise<Response> {
  const accountId = await requireAccount(request, env);
  const { results } = await env.DB.prepare(
    `SELECT t.id, t.name, t.currency FROM teams t
     JOIN team_members m ON m.team_id = t.id
     WHERE m.account_id = ? ORDER BY m.joined_at DESC`,
  )
    .bind(accountId)
    .all<{ id: string; name: string; currency: string }>();
  return json({ teams: results });
}

/**
 * 把团队登记到云端（或加入已登记的团队）。设备要证明自己持有团队密钥：
 * 第一次登记时保存“团队令牌”的哈希，之后的设备必须给出同一个令牌。
 * 团队密钥本身用服务器密钥加密后保存，用于邮箱登录后在新设备上恢复。
 */
async function linkTeam(request: Request, env: Env, teamId: string): Promise<Response> {
  const accountId = await requireAccount(request, env);
  const body = await readJson(request);
  const teamToken = typeof body.teamToken === 'string' ? body.teamToken : '';
  const key = typeof body.teamKey === 'string' ? fromBase64(body.teamKey) : new Uint8Array();
  const name = typeof body.name === 'string' ? body.name.slice(0, 100) : '';
  const currency = typeof body.currency === 'string' ? body.currency.slice(0, 8) : 'CNY';
  if (teamToken.length < 20 || key.length !== 32) throw new HttpError(400, 'invalid_team');

  const tokenHash = await sha256Hex(teamToken);
  const now = Date.now();
  const existing = await env.DB.prepare('SELECT token_hash FROM teams WHERE id = ?')
    .bind(teamId)
    .first<{ token_hash: string }>();
  if (!existing) {
    await env.DB.prepare(
      'INSERT INTO teams (id, name, currency, token_hash, wrapped_key, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    )
      .bind(teamId, name, currency, tokenHash, await sealTeamKey(env.KEY_WRAP_SECRET, key), now)
      .run();
  } else if (!safeEqual(existing.token_hash, tokenHash)) {
    throw new HttpError(403, 'wrong_team_key');
  } else if (name) {
    await env.DB.prepare('UPDATE teams SET name = ? WHERE id = ?').bind(name, teamId).run();
  }
  await env.DB.prepare('INSERT OR IGNORE INTO team_members (team_id, account_id, joined_at) VALUES (?, ?, ?)')
    .bind(teamId, accountId, now)
    .run();
  return json({ ok: true });
}

async function requireMember(env: Env, teamId: string, accountId: string) {
  const team = await env.DB.prepare(
    `SELECT t.name, t.currency, t.token_hash, t.wrapped_key FROM teams t
     JOIN team_members m ON m.team_id = t.id
     WHERE t.id = ? AND m.account_id = ?`,
  )
    .bind(teamId, accountId)
    .first<{ name: string; currency: string; token_hash: string; wrapped_key: string }>();
  if (!team) throw new HttpError(403, 'not_member');
  return team;
}

/** 邮箱登录后在新设备上恢复团队：取回团队密钥。 */
async function teamKey(request: Request, env: Env, teamId: string): Promise<Response> {
  const team = await requireMember(env, teamId, await requireAccount(request, env));
  const key = await openTeamKey(env.KEY_WRAP_SECRET, team.wrapped_key);
  return json({ teamKey: toBase64(key), name: team.name, currency: team.currency });
}

/** 同步和图片接口：需要登录且是成员，并再次出示团队令牌。 */
async function requireTeamDevice(request: Request, env: Env, teamId: string): Promise<void> {
  const team = await requireMember(env, teamId, await requireAccount(request, env));
  const token = request.headers.get('X-Team-Token') ?? '';
  if (!safeEqual(team.token_hash, await sha256Hex(token))) throw new HttpError(403, 'wrong_team_key');
}

/** 打开同步连接。 */
async function openSync(request: Request, env: Env, teamId: string): Promise<Response> {
  if (request.headers.get('Upgrade') !== 'websocket') throw new HttpError(426, 'expected_websocket');
  await requireTeamDevice(request, env, teamId);
  const stub = env.TEAM.get(env.TEAM.idFromName(teamId));
  return stub.fetch(request);
}

// ---------- 图片 ----------
// 设备用团队密钥加密后上传，服务器只保管密文。同名文件已存在时不覆盖。

async function putMedia(request: Request, env: Env, teamId: string, name: string): Promise<Response> {
  await requireTeamDevice(request, env, teamId);
  const declared = Number(request.headers.get('Content-Length') ?? '0');
  if (declared > MAX_MEDIA_BYTES) throw new HttpError(413, 'too_large');
  const key = `${teamId}/${name}`;
  if (await env.MEDIA.head(key)) return json({ ok: true });
  const body = await request.arrayBuffer();
  if (body.byteLength === 0) throw new HttpError(400, 'empty');
  if (body.byteLength > MAX_MEDIA_BYTES) throw new HttpError(413, 'too_large');
  await env.MEDIA.put(key, body);
  const stub = env.TEAM.get(env.TEAM.idFromName(teamId));
  await stub.fetch(new Request('https://team/media-ready', { method: 'POST' }));
  return json({ ok: true });
}

async function getMedia(request: Request, env: Env, teamId: string, name: string): Promise<Response> {
  await requireTeamDevice(request, env, teamId);
  const object = await env.MEDIA.get(`${teamId}/${name}`);
  if (!object) throw new HttpError(404, 'not_found');
  return new Response(object.body, {
    headers: { 'Content-Type': 'application/octet-stream', 'Content-Length': `${object.size}` },
  });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
