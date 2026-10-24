-- 账号（邮箱登录）
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

-- 邮箱验证码：只存哈希
CREATE TABLE login_codes (
  email TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  sent_at INTEGER NOT NULL,
  day TEXT NOT NULL,
  sent_today INTEGER NOT NULL DEFAULT 1
);

-- 登录会话：只存令牌哈希
CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX idx_sessions_account ON sessions (account_id);

-- 团队：token_hash 用来验证设备确实持有团队密钥；wrapped_key 是用服务器密钥加密后的团队密钥（用于邮箱恢复）
CREATE TABLE teams (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  currency TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  wrapped_key TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE team_members (
  team_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (team_id, account_id)
);
CREATE INDEX idx_members_account ON team_members (account_id);
