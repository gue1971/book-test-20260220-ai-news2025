#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY required"; exit 1; }
OUT_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v6"

ok=0
for attempt in 1 2 3 4 5; do
  echo "llama only attempt ${attempt}"
  if curl --max-time 90 -sS -X POST -H 'Content-Type: application/json' \
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
[[ $ok -eq 1 ]] || { echo "llama generation failed" >&2; exit 2; }

python3 - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
base=Path('/Users/gue1971/MyWorks/ai-news/character_bible_v6')
order=[
 ('chappy','チャッピー 16 固定'),('kuroko','クロコ 16 女性 固定'),('gemmy','ジェミー皇 25 固定'),
 ('shinen','深淵将軍 16 固定'),('llama','ラマ 20代 再調整'),('grok','グロック 25 固定'),('cursor','カーソル少年 13 固定')
]
sheet=Image.new('RGB',(1160,4*410+20),(242,242,242))
for i,(key,label) in enumerate(order):
    im=Image.open(base/f'{key}.jpg').convert('RGB')
    im=ImageOps.fit(im,(520,320),method=Image.Resampling.LANCZOS)
    card=Image.new('RGB',(560,390),(250,250,250))
    d=ImageDraw.Draw(card)
    card.paste(im,(20,52))
    d.rectangle([20,52,539,371],outline=(35,35,35),width=2)
    d.rectangle([20,12,420,42],fill=(235,235,235),outline=(35,35,35),width=2)
    d.text((28,18),label,fill=(20,20,20))
    r=i//2; c=i%2
    sheet.paste(card,(20+c*570,20+r*410))
out=base/'character_bible_v6_sheet.jpg'
sheet.save(out,quality=95)
print(out)
PY

ls -lh "$OUT_DIR"/llama.jpg "$OUT_DIR"/character_bible_v6_sheet.jpg
