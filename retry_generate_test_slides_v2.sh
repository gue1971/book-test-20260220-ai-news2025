#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
OUT="$BASE/test_slides_v2"
mkdir -p "$OUT"

python3 - <<'PY'
import json, pathlib
base=pathlib.Path('/Users/gue1971/MyWorks/ai-news')
slides=json.loads((base/'SLIDES_FINAL_LOCK_JA.json').read_text(encoding='utf-8'))['slides']
focus=json.loads((base/'SLIDE_FOCUS_LOCK_JA.json').read_text(encoding='utf-8'))['focus']
ref_path=base/'character_bible_v6'/'character_bible_v6_sheet.jpg'
ref_b64=__import__('base64').b64encode(ref_path.read_bytes()).decode('ascii')
sel=[1,9,16]
for n in sel:
    s=slides[n-1]
    b='\\n'.join([f"- {x[0]}: {x[1]}" for x in s['bubbles']])
    prompt=f"""カラー固定・低頭身デフォルメ固定・日本語のみ。キャラはv6準拠。
参照画像（キャラ確定シート）に厳密準拠。1枚1主役。主役:{focus[n-1]}。

【キャラ固定ルール】
- チャッピー: 16歳男性。赤系アクセント。人間。
- クロコ: 16歳女性。青系。眼鏡。知的。人間。絶対にワニ/トカゲ/爬虫類/獣にしない。
- 深淵将軍: 16歳男性。中華風の鎧意匠。人間。
- ジェミー王: 25歳男性。金青白の王装。人間。
- ラマ: 20代男性。長髪。二面性ある表情。人間。
- グロック: 25歳男性。サイバーパンク。人間。
- カーソル: 13歳男性。短髪。橙パーカー。人間。

【絶対禁止】
- 動物化、爬虫類化、怪物化、ロボ化、年齢や性別の改変
- モノクロ、英語文字、別画風混入、キャラ差し替え

ページ:{n}
見出し:{s['title']}
ナレーション:{s['narration']}
吹き出し:\n{b}
禁止:モノクロ/英語/キャラ崩れ/動物化/ロボ化""".strip()
    req={
      "contents":[{"parts":[
        {"text":prompt},
        {"inlineData":{"mimeType":"image/jpeg","data":ref_b64}}
      ]}],
      "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
    }
    (base/'test_slides_v2'/f'slide_{n}.request.json').write_text(json.dumps(req,ensure_ascii=False),encoding='utf-8')
PY

for n in 1 9 16; do
  echo "== slide ${n} =="
  ok=0
  for attempt in 1 2 3 4 5 6 7 8; do
    echo "attempt ${attempt}"
    curl --max-time 90 -sS -X POST \
      -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$OUT/slide_${n}.request.json" > "$OUT/slide_${n}.response.json" || true

    if python3 - <<'PY' "$OUT/slide_${n}.response.json" "$OUT/slide_${n}.jpg"
import json,base64,sys
p=sys.argv[1]; out=sys.argv[2]
try:
    data=json.load(open(p,encoding='utf-8'))
except Exception:
    raise SystemExit(3)
if 'error' in data:
    print('api_error', data['error'].get('code'), data['error'].get('status'))
    raise SystemExit(4)
img=None
for c in data.get('candidates',[]):
    for part in c.get('content',{}).get('parts',[]):
        inline=part.get('inlineData') or part.get('inline_data')
        if inline and inline.get('data'):
            img=inline['data']; break
    if img: break
if not img:
    print('no_image')
    raise SystemExit(5)
open(out,'wb').write(base64.b64decode(img))
print('ok',out)
PY
    then
      ok=1
      break
    fi
    sleep 6
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

ls -lh "$OUT"/*.jpg
