#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }

SRC_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v5"
OUT_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v6"
mkdir -p "$OUT_DIR"

# Keep all non-llama fixed
cp "$SRC_DIR/chappy.jpg" "$OUT_DIR/chappy.jpg"
cp "$SRC_DIR/kuroko.jpg" "$OUT_DIR/kuroko.jpg"
cp "$SRC_DIR/gemmy.jpg" "$OUT_DIR/gemmy.jpg"
cp "$SRC_DIR/shinen.jpg" "$OUT_DIR/shinen.jpg"
cp "$SRC_DIR/grok.jpg" "$OUT_DIR/grok.jpg"
cp "$SRC_DIR/cursor.jpg" "$OUT_DIR/cursor.jpg"

# Llama only regenerate with explicit improvement constraints
cat > "$OUT_DIR/llama_prompt.txt" <<'EOF'
ラマ（20代前半男性）を再生成。日本の少年マンガ風、フルカラー、低頭身デフォルメ（3頭身前後）。

改善点（厳守）:
1) 頭身: 2.8〜3.2頭身で固定。手足を長くしすぎない。
2) 輪郭: 顔の縦長を避け、丸みのある輪郭にする。
3) 線: 主線の太さはチャッピー/クロコと同程度の太め。
4) 目: 他キャラと同程度の大きさ・情報量（小さすぎ禁止）。
5) 塗り: 陰影は2段階まで。写実寄りの陰影は禁止。
6) 色: 彩度は中程度。極端なくすみ/渋すぎを避ける。
7) 構図: 5カットは他キャラと同じテンポ（正面バスト/横顔バスト/真剣/微笑/怒り）。
8) 髪型: 長めセンターパート（v5の方向性）を維持。
9) 印象: 軽口を言う策士。いたずらっぽさと知性の両立。

禁止:
- 写実頭身
- 海外リアル系コミック調
- モノクロ
- 英語文字/日本語文字の描画
- 動物化、怪物化、ロボ化
EOF

python3 - <<'PY' "$OUT_DIR/llama_prompt.txt" "$OUT_DIR/llama.json"
import json,sys
prompt=open(sys.argv[1],'r',encoding='utf-8').read()
payload={
  "contents":[{"parts":[{"text":prompt}]}],
  "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
}
with open(sys.argv[2],'w',encoding='utf-8') as f:
    json.dump(payload,f,ensure_ascii=False)
PY

ok=0
for attempt in 1 2 3 4; do
  echo "llama attempt ${attempt}"
  if curl --max-time 120 -sS -X POST -H 'Content-Type: application/json' \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
    -d @"$OUT_DIR/llama.json" > "$OUT_DIR/llama_resp.json"; then
    if python3 - <<'PY' "$OUT_DIR/llama_resp.json" "$OUT_DIR/llama.jpg"
import json,base64,sys
with open(sys.argv[1],'r',encoding='utf-8') as f: data=json.load(f)
img=None
for cand in data.get('candidates',[]):
    for part in cand.get('content',{}).get('parts',[]):
        inline=part.get('inlineData') or part.get('inline_data')
        if inline and inline.get('data'):
            img=inline['data']; break
    if img: break
if not img: raise SystemExit(2)
with open(sys.argv[2],'wb') as f: f.write(base64.b64decode(img))
print(sys.argv[2])
PY
    then ok=1; break; fi
  fi
  sleep 2
done
[[ $ok -eq 1 ]] || { echo "failed llama" >&2; exit 2; }

python3 - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
base=Path('/Users/gue1971/MyWorks/ai-news/character_bible_v6')
order=[
 ('chappy','チャッピー 16 固定'),('kuroko','クロコ 16 女性 固定'),('gemmy','ジェミー皇 25 固定'),
 ('shinen','深淵将軍 16 固定'),('llama','ラマ 20代 再調整'),('grok','グロック 25 固定'),('cursor','カーソル少年 13 固定')
]
cards=[]
for key,label in order:
    im=Image.open(base/f'{key}.jpg').convert('RGB')
    im=ImageOps.fit(im,(520,320),method=Image.Resampling.LANCZOS)
    card=Image.new('RGB',(560,390),(250,250,250))
    d=ImageDraw.Draw(card)
    card.paste(im,(20,52))
    d.rectangle([20,52,539,371],outline=(35,35,35),width=2)
    d.rectangle([20,12,420,42],fill=(235,235,235),outline=(35,35,35),width=2)
    d.text((28,18),label,fill=(20,20,20))
    cards.append(card)
sheet=Image.new('RGB',(1160,4*410+20),(242,242,242))
for i,card in enumerate(cards):
    r=i//2; c=i%2
    sheet.paste(card,(20+c*570,20+r*410))
out=base/'character_bible_v6_sheet.jpg'
sheet.save(out,quality=95)
print(out)
PY

ls -lh "$OUT_DIR"/*.jpg
