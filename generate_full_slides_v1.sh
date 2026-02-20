#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
OUT="$BASE/slides_v1"
mkdir -p "$OUT"

python3 - <<'PY'
import json, pathlib
base=pathlib.Path('/Users/gue1971/MyWorks/ai-news')
slides=json.loads((base/'SLIDES_FINAL_LOCK_JA.json').read_text(encoding='utf-8'))['slides']
focus=json.loads((base/'SLIDE_FOCUS_LOCK_JA.json').read_text(encoding='utf-8'))['focus']
ref_path=base/'character_bible_v6'/'character_bible_v6_sheet.jpg'
ref_b64=__import__('base64').b64encode(ref_path.read_bytes()).decode('ascii')
out=base/'slides_v1'
out.mkdir(exist_ok=True)
for i,s in enumerate(slides, start=1):
    b='\\n'.join([f"- {name}: {line}" for name,line in s['bubbles']])
    prompt=f"""カラー固定。低頭身デフォルメ固定。日本語のみ。キャラはv6固定準拠。
参照画像（キャラ確定シート）に厳密準拠。
1枚1主役。主役:{focus[i-1]}。他キャラは補助。

【キャラ固定ルール】
- チャッピー: 16歳男性。赤系アクセント。人間。
- クロコ: 16歳女性。青系。眼鏡。知的。人間。絶対にワニ/トカゲ/爬虫類/獣にしない。
- 深淵将軍: 16歳男性。中華風の鎧意匠。人間。
- ジェミー王: 25歳男性。金青白の王装。人間。
- ラマ: 20代男性。長髪。二面性ある表情。人間。
- グロック: 25歳男性。サイバーパンク。人間。
- カーソル: 13歳男性。短髪。橙パーカー。人間。

ページ:{i}
見出し:{s['title']}
ナレーション:{s['narration']}
吹き出し:\n{b}
解説:{s['onsite']}
禁止:モノクロ/英語/キャラ崩れ/動物化/ロボ化/文字化け/年齢性別改変
"""
    req={
      "contents":[{"parts":[
        {"text":prompt},
        {"inlineData":{"mimeType":"image/jpeg","data":ref_b64}}
      ]}],
      "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
    }
    (out/f'slide_{i:02d}.request.json').write_text(json.dumps(req,ensure_ascii=False),encoding='utf-8')
print('requests generated')
PY

for i in {1..18}; do
  n=$(printf "%02d" "$i")
  echo "== slide ${n} =="
  ok=0
  for attempt in 1 2 3 4 5 6 7 8; do
    echo "attempt ${attempt}"
    curl --max-time 90 -sS -X POST -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$OUT/slide_${n}.request.json" > "$OUT/slide_${n}.response.json" || true

    if python3 - <<'PY' "$OUT/slide_${n}.response.json" "$OUT/slide_${n}.jpg"
import json,base64,sys
p=sys.argv[1]; out=sys.argv[2]
try:
    data=json.load(open(p,encoding='utf-8'))
except Exception:
    raise SystemExit(2)
if 'error' in data:
    print('api_error', data['error'].get('code'), data['error'].get('status'))
    raise SystemExit(3)
img=None
for c in data.get('candidates',[]):
    for part in c.get('content',{}).get('parts',[]):
        inline=part.get('inlineData') or part.get('inline_data')
        if inline and inline.get('data'):
            img=inline['data']; break
    if img: break
if not img:
    print('no_image')
    raise SystemExit(4)
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

echo 'all slides generated'
ls -lh "$OUT"/slide_*.jpg
