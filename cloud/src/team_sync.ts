import { DurableObject } from 'cloudflare:workers';

/**
 * 一个团队的云端同步节点（每个团队一个实例，自带 SQLite）。
 *
 * 只保管同步记录：来源设备 + 序号是明文（用来算谁缺什么），内容是设备用团队密钥
 * 加密过的密文，服务器解不开。协议和设备之间的局域网同步一致：
 *   设备 → hello { vv }        服务器 → hello { vv }，随后把设备缺的记录分批发过去
 *   设备 → ops [{ o, s, c }]   服务器存下连续的部分，并实时转发给同团队其他在线设备
 * 有设备传上新图片时（Worker 调 POST /media-ready），通知所有在线设备 media-ready，
 * 缺图的设备马上去取，不用等下一次重试。
 */

type Op = { o: string; s: number; c: string };
type VersionVector = Record<string, number>;
type Attachment = { vv: VersionVector; ready: boolean };

const BATCH = 200;

export class TeamSync extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.storage.sql.exec(
      'CREATE TABLE IF NOT EXISTS ops (origin TEXT NOT NULL, seq INTEGER NOT NULL, data TEXT NOT NULL, PRIMARY KEY (origin, seq))',
    );
  }

  async fetch(request: Request): Promise<Response> {
    if (request.method === 'POST' && new URL(request.url).pathname === '/media-ready') {
      this.notifyAll({ type: 'media-ready' });
      return new Response(null, { status: 204 });
    }
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('expected websocket', { status: 426 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    // 用可休眠的 WebSocket：没有消息时不占计算时间。
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ vv: {}, ready: false } satisfies Attachment);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== 'string') return;
    let message: { type?: string; vv?: VersionVector; ops?: Op[] };
    try {
      message = JSON.parse(raw);
    } catch {
      ws.close(1003, 'bad message');
      return;
    }
    if (message.type === 'hello') {
      const att: Attachment = { vv: sanitizeVector(message.vv), ready: true };
      ws.serializeAttachment(att);
      ws.send(JSON.stringify({ type: 'hello', vv: this.vector() }));
      this.sendMissing(ws, att);
    } else if (message.type === 'ops' && Array.isArray(message.ops)) {
      const stored = this.store(message.ops);
      const att = ws.deserializeAttachment() as Attachment;
      for (const op of message.ops) bump(att.vv, op);
      ws.serializeAttachment(att);
      if (stored.length > 0) this.broadcast(ws, stored);
    }
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    ws.close(code, 'closing');
  }

  /** 服务器拥有的每个来源设备的最大序号。 */
  private vector(): VersionVector {
    const vv: VersionVector = {};
    for (const row of this.ctx.storage.sql.exec<{ origin: string; seq: number }>(
      'SELECT origin, MAX(seq) AS seq FROM ops GROUP BY origin',
    )) {
      vv[row.origin] = row.seq;
    }
    return vv;
  }

  /** 只存与已有记录连续的部分（同一来源按序号 1、2、3… 不能跳）。 */
  private store(ops: Op[]): Op[] {
    const vv = this.vector();
    const stored: Op[] = [];
    for (const op of ops) {
      if (!isOp(op)) continue;
      const expected = (vv[op.o] ?? 0) + 1;
      if (op.s !== expected) continue;
      this.ctx.storage.sql.exec('INSERT INTO ops (origin, seq, data) VALUES (?, ?, ?)', op.o, op.s, op.c);
      vv[op.o] = op.s;
      stored.push(op);
    }
    return stored;
  }

  /** 把服务器有、这台设备没有的记录分批发过去。 */
  private sendMissing(ws: WebSocket, att: Attachment): void {
    const mine = this.vector();
    for (const [origin, max] of Object.entries(mine)) {
      let from = att.vv[origin] ?? 0;
      while (from < max) {
        const rows = [
          ...this.ctx.storage.sql.exec<{ seq: number; data: string }>(
            'SELECT seq, data FROM ops WHERE origin = ? AND seq > ? ORDER BY seq LIMIT ?',
            origin,
            from,
            BATCH,
          ),
        ];
        if (rows.length === 0) break;
        const ops = rows.map((r) => ({ o: origin, s: r.seq, c: r.data }));
        ws.send(JSON.stringify({ type: 'ops', ops }));
        from = rows[rows.length - 1].seq;
      }
      att.vv[origin] = Math.max(att.vv[origin] ?? 0, from);
    }
    ws.serializeAttachment(att);
  }

  private notifyAll(message: unknown): void {
    const text = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      const att = ws.deserializeAttachment() as Attachment | null;
      if (!att?.ready) continue;
      try {
        ws.send(text);
      } catch {
        // 连接已断开，重连后会自己检查缺哪些图片。
      }
    }
  }

  /** 新存下的记录实时推给同团队其他在线设备。 */
  private broadcast(sender: WebSocket, ops: Op[]): void {
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === sender) continue;
      const att = ws.deserializeAttachment() as Attachment | null;
      if (!att?.ready) continue;
      const missing = ops.filter((op) => (att.vv[op.o] ?? 0) < op.s);
      if (missing.length === 0) continue;
      try {
        ws.send(JSON.stringify({ type: 'ops', ops: missing }));
        for (const op of missing) bump(att.vv, op);
        ws.serializeAttachment(att);
      } catch {
        // 连接已断开，等它重连时会按版本向量补齐。
      }
    }
  }
}

function isOp(value: unknown): value is Op {
  const op = value as Op;
  return (
    typeof op === 'object' &&
    op !== null &&
    typeof op.o === 'string' &&
    op.o.length > 0 &&
    op.o.length <= 64 &&
    Number.isInteger(op.s) &&
    op.s > 0 &&
    typeof op.c === 'string' &&
    op.c.length <= 64 * 1024
  );
}

function bump(vv: VersionVector, op: Op): void {
  if (isOp(op) && (vv[op.o] ?? 0) < op.s) vv[op.o] = op.s;
}

function sanitizeVector(value: unknown): VersionVector {
  const vv: VersionVector = {};
  if (typeof value !== 'object' || value === null) return vv;
  for (const [k, v] of Object.entries(value)) {
    if (typeof v === 'number' && Number.isInteger(v) && v >= 0) vv[k] = v;
  }
  return vv;
}
