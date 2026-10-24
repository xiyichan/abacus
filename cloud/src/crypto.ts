// 服务器端用到的小工具：随机数、哈希、base64、团队密钥的加密保存。

const encoder = new TextEncoder();

export function randomBytes(length: number): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(length));
}

export function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

export function fromBase64(text: string): Uint8Array {
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export function toBase64Url(bytes: Uint8Array): string {
  return toBase64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** 长度无关的字符串比较，避免按时间猜出令牌。 */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function wrapKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', fromBase64(secret), 'AES-GCM', false, [
    'encrypt',
    'decrypt',
  ]);
}

/** 用服务器密钥（KEY_WRAP_SECRET）加密团队密钥后再存进数据库。 */
export async function sealTeamKey(secret: string, teamKey: Uint8Array): Promise<string> {
  const iv = randomBytes(12);
  const sealed = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await wrapKey(secret), teamKey);
  const out = new Uint8Array(iv.length + sealed.byteLength);
  out.set(iv);
  out.set(new Uint8Array(sealed), iv.length);
  return toBase64(out);
}

export async function openTeamKey(secret: string, wrapped: string): Promise<Uint8Array> {
  const bytes = fromBase64(wrapped);
  const clear = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: bytes.slice(0, 12) },
    await wrapKey(secret),
    bytes.slice(12),
  );
  return new Uint8Array(clear);
}
