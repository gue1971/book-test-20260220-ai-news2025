#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
OUT="$BASE/character_intro_v4"
mkdir -p "$OUT"

python3 - <<'PY'
import base64, json, pathlib
base=pathlib.Path('/Users/gue1971/MyWorks/ai-news')
out=base/'character_intro_v4'
main_anchor=base64.b64encode((base/'projectA_style'/'references'/'style_main_anchor.jpg').read_bytes()).decode('ascii')
chars=[
 ('chappy','チャッピー','16歳男性。赤ジャケットとゴーグル。'),
 ('kuroko','クロコ','16歳女性。青髪ボブ、眼鏡、青系スーツ。'),
 ('gemmy','ジェミー王','25歳男性。王装（金青白）。'),
 ('shinen','深淵将軍','16歳男性。中華風鎧意匠。人間少年顔。'),
 ('llama','ラマ','20代男性。長髪、私服ジャケット。'),
 ('grok','グロック','25歳男性。サイバーパンク装備。'),
 ('cursor','カーソル','13歳男性。橙パーカー。')
]
for key,name,detail in chars:
    ref_b64=base64.b64encode((base/'character_bible_v6'/f'{key}.jpg').read_bytes()).decode('ascii')
    prompt=f'''
日本の少年マンガ風、フルカラー、mainスタイル。
対象: {name}
要件: {detail}

体型ルール（最重要）:
- 全員を約2.8頭身で統一（2.7〜2.9）
- 頭を過度に大きくしない
- 足を極端に短くしない

構図ルール:
- 単体1人、全身1ポーズ、中央配置
- 背景は薄いブルー〜白グラデーションで統一
- 背景に小物や他人物を置かない

禁止:
- 複数ポーズ、シート化、分割
- 動物化、着ぐるみ化、ロボ化
- 文字、ロゴ、吹き出し
'''.strip()
    req={"contents":[{"parts":[{"text":prompt},{"inlineData":{"mimeType":"image/jpeg","data":main_anchor}},{"inlineData":{"mimeType":"image/jpeg","data":ref_b64}}]}],"generationConfig":{"responseModalities":["TEXT","IMAGE"]}}
    (out/f'{key}_intro.request.json').write_text(json.dumps(req,ensure_ascii=False),encoding='utf-8')
print(out)
PY

for key in chappy kuroko gemmy shinen llama grok cursor; do
  req="$OUT/${key}_intro.request.json"
  outimg="$OUT/${key}_intro.jpg"
  echo "== $key =="
  ok=0
  for a in 1 2 3 4 5 6; do
    echo "attempt $a"
    curl --max-time 120 -sS -X POST -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$req" > "$OUT/${key}_intro.response.json" || true

    if python3 - <<'PY' "$OUT/${key}_intro.response.json" "$outimg"
import json,base64,sys
p=sys.argv[1]; out=sys.argv[2]
try:
  data=json.load(open(p,encoding='utf-8'))
except Exception:
  raise SystemExit(2)
if 'error' in data:
  raise SystemExit(3)
img=None
for c in data.get('candidates',[]):
  for part in c.get('content',{}).get('parts',[]):
    inline=part.get('inlineData') or part.get('inline_data')
    if inline and inline.get('data'):
      img=inline['data']; break
  if img: break
if not img:
  raise SystemExit(4)
open(out,'wb').write(base64.b64decode(img))
print('ok',out)
PY
    then
      ok=1
      break
    fi
    sleep 3
  done
  [[ $ok -eq 1 ]] || { echo "failed $key" >&2; exit 2; }
done

ls -lh "$OUT"/*.jpg
