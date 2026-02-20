#!/bin/zsh
set -euo pipefail

API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }

BASE_DIR="/Users/gue1971/MyWorks/ai-news"
OUT_DIR="$BASE_DIR/test_slides_v2"
mkdir -p "$OUT_DIR"

python3 - <<'PY'
import json, pathlib
base = pathlib.Path('/Users/gue1971/MyWorks/ai-news')
slides = json.loads((base/'SLIDES_FINAL_LOCK_JA.json').read_text(encoding='utf-8'))['slides']
focus = json.loads((base/'SLIDE_FOCUS_LOCK_JA.json').read_text(encoding='utf-8'))['focus']
selected = [1,9,16]
out = {}
for n in selected:
    s = slides[n-1]
    out[n] = {
        'era': s['era'],
        'title': s['title'],
        'narration': s['narration'],
        'bubbles': s['bubbles'],
        'onsite': s['onsite'],
        'focus': focus[n-1]
    }
(base/'test_slides_v2'/'inputs.json').write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
print(base/'test_slides_v2'/'inputs.json')
PY

for n in 1 9 16; do
  python3 - <<'PY' "$OUT_DIR/inputs.json" "$n" "$OUT_DIR/slide_${n}.request.json"
import json,sys
inputs=json.load(open(sys.argv[1],encoding='utf-8'))
n=sys.argv[2]
out=sys.argv[3]
s=inputs[n]

def bubbles_text(b):
    return "\\n".join([f"- {name}: {line}" for name,line in b])

prompt=f"""
カラー固定。低頭身デフォルメ固定。日本の少年マンガ風。全テキスト日本語のみ。
キャラデザインは固定シート（v6）に厳密準拠。
1枚1主役ルール。主役は「{s['focus']}」。他キャラは補助。

【ページ情報】
- ページ: {n}
- 時期: {s['era']}
- 見出し: {s['title']}
- ナレーション: {s['narration']}
- 吹き出し:\n{bubbles_text(s['bubbles'])}
- 解説: {s['onsite']}

【レイアウト要件】
- スマホ縦読み1枚
- 見出し、ナレーション、吹き出しを日本語で可読配置
- 視線誘導を主役へ集中
- 情報過多にしない

【禁止】
- モノクロ、英語文字、文字化け
- 動物化、怪物化、ロボ化
- キャラ崩れ、別画風混入
""".strip()

payload={
  "contents":[{"parts":[{"text":prompt}]}],
  "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
}
json.dump(payload,open(out,'w',encoding='utf-8'),ensure_ascii=False)
print(out)
PY

  ok=0
  for attempt in 1 2 3 4; do
    echo "slide ${n} attempt ${attempt}"
    if curl --max-time 120 -sS -X POST \
      -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$OUT_DIR/slide_${n}.request.json" > "$OUT_DIR/slide_${n}.response.json"; then
      if python3 - <<'PY' "$OUT_DIR/slide_${n}.response.json" "$OUT_DIR/slide_${n}.jpg"
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
  [[ $ok -eq 1 ]] || { echo "failed slide ${n}" >&2; exit 2; }
done

python3 - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
base=Path('/Users/gue1971/MyWorks/ai-news/test_slides_v2')
order=[1,9,16]
labels={1:'1枚目 序章',9:'9枚目 カーソル',16:'16枚目 クロコ頂点'}
canvas=Image.new('RGB',(1060,1620),(242,242,242))
d=ImageDraw.Draw(canvas)
y=20
for n in order:
    im=Image.open(base/f'slide_{n}.jpg').convert('RGB')
    im=ImageOps.fit(im,(1020,500),method=Image.Resampling.LANCZOS)
    canvas.paste(im,(20,y+36))
    d.rectangle([20,y+36,1039,y+535],outline=(30,30,30),width=2)
    d.rectangle([20,y,320,y+28],fill=(235,235,235),outline=(30,30,30),width=2)
    d.text((28,y+7),labels[n],fill=(20,20,20))
    y += 540
out=base/'test_1_9_16_sheet.jpg'
canvas.save(out,quality=95)
print(out)
PY

ls -lh "$OUT_DIR"/*.jpg
