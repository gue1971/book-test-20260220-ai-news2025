#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }

OUT_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v4"
SRC_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v3"
mkdir -p "$OUT_DIR"

# Keep strict-fixed characters from v3
cp "$SRC_DIR/chappy.jpg" "$OUT_DIR/chappy.jpg"
cp "$SRC_DIR/kuroko.jpg" "$OUT_DIR/kuroko.jpg"
cp "$SRC_DIR/shinen.jpg" "$OUT_DIR/shinen.jpg"
cp "$SRC_DIR/grok.jpg" "$OUT_DIR/grok.jpg"

cat > "$OUT_DIR/targets.txt" <<'EOF'
gemmy|ジェミー皇（25歳男性）を再設計。日本の少年マンガ風、フルカラー、低頭身デフォルメ（3頭身前後）。顔を縦長にしない。頭の高さを短く、横幅を少し広くして、体との比率を自然に。年上の威厳を出す。王冠+重厚な青金白衣装。5カット: 正面バスト/横顔バスト/真剣/微笑/怒り。白背景。日本語文字は入れない。
llama|ラマ（20代前半男性）を再設計。チャッピーと明確に見分けがつくよう、髪型を長めウェーブまたはセンター分けに固定。顔つきは細い目と皮肉な笑み。服は緑・茶系の軽装コート。5カット構成。白背景。日本語文字は入れない。
cursor|カーソル少年（13歳男性）を再設計。チャッピーと明確に見分けがつくよう、髪型は短いマッシュ/前髪重めで、丸顔・大きい目の幼さを強調。オレンジフーディ固定。5カット構成。白背景。日本語文字は入れない。
EOF

while IFS='|' read -r name prompt; do
  req="$OUT_DIR/${name}.json"
  resp="$OUT_DIR/${name}_resp.json"
  img="$OUT_DIR/${name}.jpg"

  python3 - <<'PY' "$prompt" "$req"
import json,sys
prompt=sys.argv[1]; req=sys.argv[2]
text=(
  "カラー固定。低頭身デフォルメ固定。キャラは人間のみ。"
  "モノクロ禁止。英語文字禁止。"
  "禁止: 動物化、怪物化、ロボ化、全身鎧で顔隠し、チャッピーと同一髪型。"
  + prompt
)
payload={
  "contents":[{"parts":[{"text":text}]}],
  "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
}
with open(req,'w',encoding='utf-8') as f: json.dump(payload,f,ensure_ascii=False)
PY

  ok=0
  for attempt in 1 2 3 4; do
    echo "${name} attempt ${attempt}"
    if curl --max-time 120 -sS -X POST -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$req" > "$resp"; then
      if python3 - <<'PY' "$resp" "$img"
import json,base64,sys
resp=sys.argv[1]; out=sys.argv[2]
with open(resp,'r',encoding='utf-8') as f: data=json.load(f)
img=None
for cand in data.get('candidates',[]):
    for part in cand.get('content',{}).get('parts',[]):
        inline=part.get('inlineData') or part.get('inline_data')
        if inline and inline.get('data'):
            img=inline['data']; break
    if img: break
if not img: raise SystemExit(2)
with open(out,'wb') as f: f.write(base64.b64decode(img))
print(out)
PY
      then ok=1; break; fi
    fi
    sleep 2
  done
  [[ $ok -eq 1 ]] || { echo "failed ${name}" >&2; exit 2; }
done < "$OUT_DIR/targets.txt"

python3 - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
base=Path('/Users/gue1971/MyWorks/ai-news/character_bible_v4')
order=[
 ('chappy','チャッピー 16'),('kuroko','クロコ 16 女性'),('gemmy','ジェミー皇 25(修正)'),
 ('shinen','深淵将軍 16'),('llama','ラマ 20代(修正)'),('grok','グロック 25'),('cursor','カーソル少年 13(修正)')
]
cards=[]
for key,label in order:
    p=base/f'{key}.jpg'
    if not p.exists(): raise SystemExit(f'missing {key}')
    im=Image.open(p).convert('RGB')
    im=ImageOps.fit(im,(520,320),method=Image.Resampling.LANCZOS)
    card=Image.new('RGB',(560,390),(250,250,250))
    d=ImageDraw.Draw(card)
    card.paste(im,(20,52))
    d.rectangle([20,52,539,371],outline=(35,35,35),width=2)
    d.rectangle([20,12,360,42],fill=(235,235,235),outline=(35,35,35),width=2)
    d.text((28,18),label,fill=(20,20,20))
    cards.append(card)
cols=2; rows=4
sheet=Image.new('RGB',(1160,rows*410+20),(242,242,242))
for i,card in enumerate(cards):
    r=i//cols; c=i%cols
    x=20+c*570; y=20+r*410
    sheet.paste(card,(x,y))
out=base/'character_bible_v4_sheet.jpg'
sheet.save(out,quality=95)
print(out)
PY

ls -lh "$OUT_DIR"/*.jpg
