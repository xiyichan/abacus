#!/bin/bash
# 把 raw/ 里的模拟器截图（iPhone 17，1206×2622）排成 Play 商店要的 1080×1920 宣传图。
#   ./make_screens.sh zh    或    ./make_screens.sh en
# 截图本身用 app/tool/screenshot_demo.dart 灌好演示数据后截取。
set -e
cd "$(dirname "$0")"
LANG_CODE=${1:-zh}
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WORK=$(mktemp -d)
mkdir -p screens

if [ "$LANG_CODE" = en ]; then
  CAPTIONS=(
    "1-pos|Tap to sell|Totals and change, worked out for you"
    "2-products|Stock at a glance|Photos, prices and variants by category"
    "3-orders|Every sale recorded|Orders by event, ready to export"
    "4-stats|Close out in seconds|Revenue, expenses and profit per event"
    "5-bestsellers|Know what sells|Plan your next restock with the bestseller list"
  )
else
  CAPTIONS=(
    "1-pos|点一点就能结账|自动计算总价和找零"
    "2-products|商品和库存，一目了然|分类、图片、价格、规格都清楚"
    "3-orders|每一单都有记录|按场次查看订单，随时导出"
    "4-stats|展后对账不头疼|收入、支出、净收入自动算好"
    "5-bestsellers|什么卖得好，一看便知|热销榜帮你决定下次备货"
  )
fi

for entry in "${CAPTIONS[@]}"; do
  IFS='|' read -r name title subtitle <<< "$entry"
  src="$PWD/raw/$LANG_CODE-$name.png"
  [ -f "$src" ] || { echo "missing $src"; exit 1; }
  # 截图裁掉顶部状态栏（含调试角标）和底部 40px，剩 1206×2402，缩到 780 宽。
  cat > "$WORK/$name.html" <<EOF
<!doctype html><html><head><meta charset="utf-8"><style>
*{margin:0;box-sizing:border-box}
html,body{width:1080px;height:1920px;overflow:hidden}
body{background:#FFE4E1;font-family:"PingFang SC","Hiragino Sans GB",-apple-system,sans-serif;position:relative}
.blob{position:absolute;border-radius:50%;background:#FFD1DC}
.b1{width:760px;height:760px;left:-260px;top:-320px}
.b2{width:520px;height:520px;right:-220px;bottom:180px;opacity:.75}
.cap{position:absolute;top:100px;left:80px;right:80px;text-align:center}
h1{font-size:76px;font-weight:700;color:#B4465A;line-height:1.2;letter-spacing:2px}
p{font-size:40px;font-weight:500;color:#401518;margin-top:22px;line-height:1.35}
.shot{position:absolute;left:150px;top:360px;width:780px;height:1534px;overflow:hidden;
  border-radius:56px;border:10px solid #fff;box-shadow:0 30px 70px rgba(64,21,24,.18)}
.shot img{display:block;width:760px;margin-top:-113px}
</style></head><body>
<div class="blob b1"></div><div class="blob b2"></div>
<div class="cap"><h1>$title</h1><p>$subtitle</p></div>
<div class="shot"><img src="file://$src"></div>
</body></html>
EOF
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --window-size=1080,1920 \
    --screenshot="$PWD/screens/$LANG_CODE-$name.png" "file://$WORK/$name.html" >/dev/null 2>&1
done
rm -rf "$WORK"
ls -1 screens/$LANG_CODE-*.png
