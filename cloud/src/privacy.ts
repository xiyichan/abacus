/**
 * 隐私政策页面（GET /privacy）。Google Play / App Store 的商品详情和 App 设置页都链接到这里。
 * 内容要和代码实际行为一致：改了收集或存储的数据，记得同步修改这里和生效日期。
 */

const CONTACT_EMAIL = 'lifeng@naturoeye.com';
const UPDATED = '2026-11-06';

export function privacyPage(): Response {
  return new Response(HTML, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

const HTML = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>小算盘隐私政策 · Abacus Privacy Policy</title>
<style>
  :root { --bg: #fff; --fg: #1c1c1e; --muted: #6e6e73; --line: #e5e5ea; --accent: #b4532a; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #1c1c1e; --fg: #f2f2f7; --muted: #a1a1a6; --line: #38383a; --accent: #f0a27a; }
  }
  body { margin: 0; background: var(--bg); color: var(--fg);
    font: 16px/1.7 -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans CJK SC", "Segoe UI", sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }
  h1 { font-size: 28px; line-height: 1.3; margin: 0 0 4px; }
  h2 { font-size: 20px; margin: 36px 0 8px; padding-top: 8px; border-top: 1px solid var(--line); }
  h3 { font-size: 17px; margin: 24px 0 4px; }
  p, li { margin: 6px 0; }
  ul { padding-left: 22px; }
  a { color: var(--accent); }
  .muted { color: var(--muted); font-size: 14px; }
  nav { margin: 16px 0 0; font-size: 15px; }
  hr { border: 0; border-top: 2px solid var(--line); margin: 56px 0 0; }
</style>
</head>
<body>
<main>

<h1>小算盘隐私政策</h1>
<p class="muted">生效日期：${UPDATED}</p>
<nav><a href="#en">English version below</a> · <a href="#delete">删除账号与数据</a></nav>

<p>小算盘（英文名 Abacus，以下称“本应用”）是一款面向同人展、市集摊主的收银与库存工具，由个人开发者开发和运营（以下称“我们”）。本政策说明本应用以及云端同步服务（abacus.naturoeye.com）会处理哪些信息、为什么处理、存放在哪里，以及你如何删除它们。</p>

<h2>一、概要</h2>
<ul>
  <li>不登录也能使用全部收银、库存、订单和统计功能，此时<strong>所有数据只保存在你的设备上</strong>。</li>
  <li>只有当你主动开启<strong>云端同步</strong>时，才需要用邮箱登录。商品、订单等业务数据在你的设备上加密后才会上传。</li>
  <li>本应用<strong>没有广告</strong>，不使用任何统计分析或追踪 SDK，不收集广告 ID，不出售任何数据。</li>
</ul>

<h2>二、保存在你设备上的数据</h2>
<p>你在本应用中录入的商品（名称、价格、库存、图片）、订单、场次、支出、收款码图片、收银锁 PIN 等，都保存在本应用的本地数据库中。这些数据不会发送给我们，除非你开启了下文所述的同步功能。卸载本应用会删除这些本地数据。</p>

<h2>三、局域网同步</h2>
<p>同一团队的多台设备可以在同一局域网（Wi-Fi）内直接互相同步。设备之间传输的内容用团队密钥（AES-256-GCM）加密，数据不经过我们的服务器。团队密钥包含在团队邀请二维码中，<strong>请只把邀请二维码给你信任的队友</strong>。</p>

<h2>四、云端同步（可选）</h2>
<p>开启云端同步后，我们的服务器会处理以下信息：</p>
<ul>
  <li><strong>邮箱地址</strong>：用于登录和接收验证码。</li>
  <li><strong>显示名称</strong>（可选）：你自己设置的用户名，用于在团队中显示。</li>
  <li><strong>登录验证码和登录令牌</strong>：服务器只保存它们的哈希值。验证码 10 分钟后失效，登录令牌 180 天后失效。</li>
  <li><strong>团队信息</strong>：团队名称、货币、创建时间，以及哪些账号属于该团队。</li>
  <li><strong>同步记录和图片</strong>：商品、订单等变更记录和商品图片、收款码图片，在你的设备上用团队密钥加密后才上传。服务器保存的是密文，以及用于同步的设备编号和记录序号。</li>
  <li><strong>用于找回的团队密钥</strong>：为了让你在新设备上用邮箱登录后能恢复团队，服务器会保存一份用服务器密钥加密的团队密钥。这意味着在技术上，我们能够解密你的团队数据。我们不会这样做，除非为排查你主动请求处理的问题，或依照法律要求。</li>
</ul>
<p>此外，为了安全和运维，服务器的运行平台会短期记录请求日志（例如 IP 地址、请求时间、请求路径），这些日志会定期自动清除。</p>

<h2>五、我们使用的第三方服务</h2>
<ul>
  <li><strong>Cloudflare</strong>：云端同步服务部署在 Cloudflare（Workers、D1、Durable Objects、R2）上，上述云端数据存储在 Cloudflare 的基础设施中。</li>
  <li><strong>Resend</strong>：用于发送登录验证码邮件。我们会把你的邮箱地址和验证码交给 Resend 以发送邮件。</li>
  <li><strong>Google Play / Apple App Store</strong>：“请作者喝杯咖啡”的打赏通过应用商店的应用内购买完成。付款信息由 Google 或 Apple 处理，我们无法获取你的银行卡等支付信息，只会收到交易是否成功的结果。</li>
</ul>
<p>除上述为提供服务所必需的情况外，我们不会向任何第三方分享你的信息。</p>

<h2>六、设备权限</h2>
<ul>
  <li><strong>相机</strong>：仅用于扫描团队邀请二维码。画面只在设备上实时识别，不会保存或上传。</li>
  <li><strong>相册 / 照片</strong>：仅在你选择商品图片或收款码图片时读取你选中的图片。</li>
  <li><strong>本地网络</strong>：用于在局域网内发现同一团队的其他设备并同步数据。</li>
  <li><strong>网络</strong>：用于云端同步和应用内购买。</li>
</ul>

<h2 id="delete">七、删除账号与数据</h2>
<ul>
  <li><strong>本地数据</strong>：卸载本应用即可删除设备上的全部数据。</li>
  <li><strong>云端账号和数据</strong>：请用你登录时使用的邮箱发送邮件至 <a href="mailto:${CONTACT_EMAIL}?subject=%E5%88%A0%E9%99%A4%E5%B0%8F%E7%AE%97%E7%9B%98%E8%B4%A6%E5%8F%B7">${CONTACT_EMAIL}</a>，标题写“删除小算盘账号”。我们会在 30 天内删除你的账号、显示名称、登录记录和团队成员关系。如果某个团队删除后不再有其他成员，我们会同时删除该团队的同步记录、图片和用于找回的团队密钥。</li>
  <li>团队其他成员设备上已同步的数据由他们各自保管，不受影响。</li>
</ul>

<h2>八、数据保存期限</h2>
<p>云端数据会一直保存到你删除账号，或团队不再有任何成员为止。过期的验证码和登录令牌会失效，不能再使用。</p>

<h2>九、儿童</h2>
<p>本应用面向经营摊位的成年人，不以儿童为目标用户，也不会在知情的情况下收集儿童的个人信息。</p>

<h2>十、政策更新</h2>
<p>如果本政策有更新，我们会在此页面公布新版本并更新生效日期。重大变更会在应用内提示。</p>

<h2>十一、联系我们</h2>
<p>对本政策有任何疑问，或希望查询、更正、删除你的信息，请发送邮件至 <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>。</p>

<hr>

<h1 id="en">Abacus Privacy Policy</h1>
<p class="muted">Effective date: ${UPDATED}</p>

<p>Abacus (小算盘, "the app") is a point-of-sale and inventory tool for convention and market stall sellers, developed and operated by an independent developer ("we"). This policy explains what information the app and its cloud sync service (abacus.naturoeye.com) process, why, where it is stored, and how you can delete it.</p>

<h2>Summary</h2>
<ul>
  <li>All checkout, inventory, order and statistics features work without an account. In that case <strong>all data stays on your device</strong>.</li>
  <li>An email sign-in is only needed if you turn on <strong>cloud sync</strong>. Business data is encrypted on your device before it is uploaded.</li>
  <li>The app has <strong>no ads</strong>, no analytics or tracking SDKs, does not collect the advertising ID, and never sells data.</li>
</ul>

<h2>Data stored on your device</h2>
<p>Products (names, prices, stock, images), orders, events, expenses, payment QR code images and the cashier lock PIN are stored in the app's local database. They are not sent to us unless you turn on sync. Uninstalling the app deletes this data.</p>

<h2>Local network sync</h2>
<p>Devices in the same team can sync directly over the same Wi-Fi network. Traffic between devices is encrypted with the team key (AES-256-GCM) and does not pass through our servers. The team key is contained in the team invite QR code, so <strong>only share invite codes with teammates you trust</strong>.</p>

<h2>Cloud sync (optional)</h2>
<p>If you turn on cloud sync, our server processes:</p>
<ul>
  <li><strong>Email address</strong>, for sign-in and verification codes.</li>
  <li><strong>Display name</strong> (optional), shown to your team.</li>
  <li><strong>Verification codes and session tokens</strong>, stored only as hashes. Codes expire after 10 minutes, sessions after 180 days.</li>
  <li><strong>Team information</strong>: team name, currency, creation time, and which accounts belong to the team.</li>
  <li><strong>Sync records and images</strong>: changes to products, orders and so on, plus product and payment QR images, encrypted on your device with the team key before upload. The server stores the ciphertext together with device and sequence numbers used for syncing.</li>
  <li><strong>Recovery copy of the team key</strong>: so you can restore a team on a new device after signing in, the server keeps a copy of the team key encrypted with a server key. This means we are technically able to decrypt your team's data. We do not do so except to investigate a problem you ask us to handle, or when required by law.</li>
</ul>
<p>For security and operations, our hosting platform keeps short-lived request logs (such as IP address, time and path), which are deleted automatically.</p>

<h2>Third-party services</h2>
<ul>
  <li><strong>Cloudflare</strong> hosts the sync service (Workers, D1, Durable Objects, R2); the cloud data above is stored on Cloudflare infrastructure.</li>
  <li><strong>Resend</strong> sends verification code emails; we pass your email address and the code to Resend.</li>
  <li><strong>Google Play / Apple App Store</strong> process optional tips ("Buy me a coffee") as in-app purchases. Payment details are handled by Google or Apple; we only receive whether the purchase succeeded.</li>
</ul>
<p>We do not share your information with anyone else except as needed to provide the service.</p>

<h2>Device permissions</h2>
<ul>
  <li><strong>Camera</strong>: only to scan team invite QR codes. Frames are processed on the device and never stored or uploaded.</li>
  <li><strong>Photos</strong>: only the images you pick for products or payment QR codes.</li>
  <li><strong>Local network</strong>: to find teammates' devices on the same network and sync with them.</li>
  <li><strong>Internet</strong>: for cloud sync and in-app purchases.</li>
</ul>

<h2 id="delete-en">Deleting your account and data</h2>
<ul>
  <li><strong>Local data</strong>: uninstall the app.</li>
  <li><strong>Cloud account and data</strong>: email <a href="mailto:${CONTACT_EMAIL}?subject=Delete%20my%20Abacus%20account">${CONTACT_EMAIL}</a> from the address you sign in with, with the subject "Delete my Abacus account". Within 30 days we will delete your account, display name, sessions and team memberships. If a team has no members left, we also delete its sync records, images and recovery key.</li>
  <li>Data already synced to other team members' devices stays with them.</li>
</ul>

<h2>Retention</h2>
<p>Cloud data is kept until you delete your account or a team has no members left. Expired codes and sessions can no longer be used.</p>

<h2>Children</h2>
<p>The app is intended for adults running a stall. It is not directed at children, and we do not knowingly collect children's personal information.</p>

<h2>Changes</h2>
<p>We will post any changes on this page and update the effective date. Significant changes will be announced in the app.</p>

<h2>Contact</h2>
<p>For questions, or to access, correct or delete your information, email <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>.</p>

</main>
</body>
</html>
`;
