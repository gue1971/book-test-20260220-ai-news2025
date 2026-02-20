#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
OUT_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v2"

if [[ -z "$API_KEY" ]]; then
  echo "NANOBANANA_API_KEY is required" >&2
  exit 1
fi

while IFS='|' read -r name prompt; do
  img="$OUT_DIR/${name}.jpg"
  [[ -f "$img" ]] && { echo "skip $name"; continue; }

  req="$OUT_DIR/${name}.json"
  python3 - <<'PY' "$prompt" "$req"
import json,sys
prompt=sys.argv[1]
req=sys.argv[2]
payload={
  "contents":[{"parts":[{"text":prompt+"\n\n禁止: 動物、ワニ、怪物、ロボット、全身鎧、顔が見えない兜、英語文字、他言語文字、実在人物、他作品キャラ。"}]}],
  "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
}
with open(req,'w',encoding='utf-8') as f:
    json.dump(payload,f,ensure_ascii=False)
PY

  for attempt in 1 2 3; do
    echo "${name} attempt ${attempt}"
    if curl -sS -X POST -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$req" > "$OUT_DIR/${name}_resp.json"; then
      python3 - <<'PY' "$OUT_DIR/${name}_resp.json" "$img"
import json,base64,sys
resp=sys.argv[1]
out=sys.argv[2]
with open(resp,'r',encoding='utf-8') as f:
    data=json.load(f)
img=None
for cand in data.get('candidates',[]):
    for part in cand.get('content',{}).get('parts',[]):
        inline=part.get('inlineData') or part.get('inline_data')
        if inline and inline.get('data'):
            img=inline['data']
            break
    if img:
        break
if not img:
    raise SystemExit(2)
with open(out,'wb') as f:
    f.write(base64.b64decode(img))
print('ok',out)
PY
      break
    fi
    sleep 2
  done

  [[ -f "$img" ]] || { echo "failed $name" >&2; exit 2; }

done < "$OUT_DIR/characters.txt"

python3 - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
base=Path('/Users/gue1971/MyWorks/ai-news/character_bible_v2')
order=['chappy','kuroko','gemmy','shinen','llama','grok','cursor']
imgs=[]
for n in order:
    p=base/f'{n}.jpg'
    if not p.exists():
        raise SystemExit(f'missing {p}')
    im=Image.open(p).convert('RGB')
    im=ImageOps.fit(im,(560,360),method=Image.Resampling.LANCZOS)
    imgs.append(im)
cols=2
rows=4
canvas=Image.new('RGB',(1160,rows*380+20),(245,245,245))
d=ImageDraw.Draw(canvas)
for i,im in enumerate(imgs):
    r=i//cols; c=i%cols
    x=20+c*570; y=20+r*380
    canvas.paste(im,(x,y))
    d.rectangle([x,y,x+559,y+359],outline=(40,40,40),width=2)
out=base/'character_bible_v2_sheet.jpg'
canvas.save(out,quality=95)
print(out)
PY

ls -lh "$OUT_DIR"/*.jpg
