# 小算盘 · 云端同步

Cloudflare Worker + Durable Objects（每个团队一个，内置 SQLite，保管加密后的同步记录）+ D1（账号、登录、团队登记）。

- 同步记录在设备上用团队密钥加密后才上传，服务器只看得到“哪台设备的第几条”，看不到内容。
- 团队密钥用服务器密钥 `KEY_WRAP_SECRET` 加密后保存，用于邮箱登录后在新设备上恢复团队。
- 邮箱验证码通过 [Resend](https://resend.com) 发送。

## 本地开发

```bash
npm install
npm run migrate:local
npm run dev            # http://0.0.0.0:8790
```

`.dev.vars`（不提交）里设置了 `EMAIL_MODE=log`：验证码不发邮件，直接返回给 App 并打印在终端里。

App 连本地云端：

```bash
flutter run --dart-define=CLOUD_URL=http://127.0.0.1:8790
```

真机连本地云端时把 `127.0.0.1` 换成电脑的局域网 IP。

## 两个环境

| | 生产 | 开发 |
|---|---|---|
| 地址 | https://abacus.naturoeye.com | https://abacus.dev.naturoeye.com |
| Worker | `abacus-cloud` | `abacus-cloud-dev` |
| D1 数据库 | `abacus` | `abacus-dev` |
| 部署 | `npm run deploy` | `npm run deploy:dev` |
| 建表/迁移 | `npm run migrate:remote` | `npm run migrate:remote:dev` |
| 设置密钥 | `npx wrangler secret put <名字>` | `npm run secret:dev <名字>` |
| 看实时日志 | `npm run logs` | `npm run logs:dev` |
| 本机服务器密钥备份 | `.key-wrap-secret` | `.key-wrap-secret-dev` |

两个环境的 Worker、数据库、Durable Objects、密钥都是独立的，数据互不相通。

- App 调试版（`flutter run`）默认连**开发**环境，正式版（`flutter build --release`）连**生产**环境；可以用 `--dart-define=CLOUD_URL=...` 覆盖。
- 开发环境里以 `@test.local` 结尾的邮箱不发邮件，验证码直接返回（`DEV_CODE_SUFFIX`），方便模拟器和自动测试。真实邮箱照常收邮件。生产环境没有这个设置。
- 推荐流程：改代码 → 本机 `npm run dev` 调试 → `npm run deploy:dev` 真机联调 → 没问题再 `npm run deploy`。
- 新增 `migrations/` 里的文件后，先迁移开发库，验证没问题再迁移生产库。

Cloudflare 登录保存在 `.wrangler-home/`（只属于这个项目，不影响电脑上其他项目的 wrangler 登录），上面的 npm 命令都会用它。第一次或登录过期时运行：

```bash
XDG_CONFIG_HOME="$PWD/.wrangler-home" npx wrangler login
```

## 从零部署（新账号或新环境时参考）

1. 创建 D1 数据库，把 `database_id` 填进 `wrangler.jsonc` 对应环境：
   ```bash
   XDG_CONFIG_HOME="$PWD/.wrangler-home" npx wrangler d1 create abacus --location apac
   ```
2. 建表：`npm run migrate:remote`
3. 生成服务器密钥。**这个密钥丢了，云端保存的团队密钥就再也解不开（邮箱恢复会失效），请另外妥善备份。**
   ```bash
   openssl rand -base64 32 > .key-wrap-secret
   XDG_CONFIG_HOME="$PWD/.wrangler-home" npx wrangler secret put KEY_WRAP_SECRET < .key-wrap-secret
   ```
4. 邮件：在 Resend 验证发信域名（当前是 `mail.naturoeye.com`，发件人 `noreply@mail.naturoeye.com`），创建 API Key：
   ```bash
   XDG_CONFIG_HOME="$PWD/.wrangler-home" npx wrangler secret put RESEND_API_KEY
   ```
5. 部署：`npm run deploy`（自动为自定义域名建好 DNS 和证书），然后 `curl https://abacus.naturoeye.com/health` 检查。

`EMAIL_MODE` 两个环境都是 `resend`。**不要在任何线上环境改成 `log`**，那样任何人都能拿到任意邮箱的验证码。

## 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/auth/start` | `{email}` 发送验证码（同一邮箱 1 分钟 1 次、每天 10 次） |
| POST | `/auth/verify` | `{email, code}` 返回登录令牌（180 天有效，错 5 次需重发） |
| POST | `/auth/logout` | 注销当前令牌 |
| GET | `/teams` | 当前账号下的团队 |
| POST | `/teams/:id/link` | 登记团队或加入已登记的团队（需出示由团队密钥派生的团队令牌） |
| GET | `/teams/:id/key` | 取回团队密钥（仅团队成员，用于恢复） |
| GET | `/teams/:id/sync` | WebSocket 同步（需登录 + 团队令牌） |
