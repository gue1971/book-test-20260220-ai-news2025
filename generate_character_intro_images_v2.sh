#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
OUT="$BASE/character_intro_v2"
mkdir -p "$OUT"

python3 - <<'PY'
import base64, json, pathlib
base=pathlib.Path('/Users/gue1971/MyWorks/ai-news')
out=base/'character_intro_v2'

chars=[
 ("チャッピー","chappy","16歳男性。赤ジャケットとゴーグル。元気で前進する立ち姿。"),
 ("クロコ","kuroko","16歳女性。青髪ボブ、眼鏡、スーツ。知的で落ち着いた立ち姿。"),
 ("ジェミー王","gemmy","25歳男性。王装（金青白）。威厳ある正面立ち。"),
 ("深淵将軍","shinen","16歳男性。中華風鎧意匠。人間の少年顔、静かな圧。"),
 ("ラマ","llama","20代男性。長髪、私服、二面性のある表情。"),
 ("グロック","grok","25歳男性。サイバーパンク装備。躍動感ある構え。"),
 ("カーソル","cursor","13歳男性。橙パーカー。親しみやすく機敏なポーズ。"),
]

for name,key,detail in chars:
    ref=(base/'character_bible_v6'/f'{key}.jpg').read_bytes()
    ref_b64=base64.b64encode(ref).decode('ascii')
    prompt=f"""
日本の少年マンガ風、フルカラー、低頭身デフォルメ。
キャラクター紹介ページ用の単体立ち絵を1人だけ描く。
対象: {name}
要件: {detail}

厳守:
- 参照画像の人物をそのまま描く（別キャラ禁止）
- 1人だけ描く（他人物・群像禁止）
- 体全体が入るように描く（頭や体の欠け禁止）
- 背景はシンプルで薄め、人物主役
- 文字、ロゴ、吹き出し、看板禁止
""".strip()
    req={
      "contents":[{"parts":[
        {"text":prompt},
        {"inlineData":{"mimeType":"image/jpeg","data":ref_b64}}
      ]}],
      "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
    }
    (out/f"{key}_intro.request.json").write_text(json.dumps(req,ensure_ascii=False),encoding='utf-8')
print(out)
PY

for key in chappy kuroko gemmy shinen llama grok cursor; do
  req="$OUT/${key}_intro.request.json"
  outimg="$OUT/${key}_intro.jpg"
  echo "== ${key} =="
  ok=0
  for attempt in 1 2 3 4 5 6; do
    echo "attempt $attempt"
    curl --max-time 120 -sS -X POST \
      -H 'Content-Type: application/json' \
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
    sleep 4
  done
  [[ $ok -eq 1 ]] || { echo "failed $key" >&2; exit 2; }
done

ls -lh "$OUT"/*.jpg
