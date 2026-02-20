#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
OUT="$BASE/character_intro_v1"
mkdir -p "$OUT"

python3 - <<'PY'
import base64, json, pathlib
base=pathlib.Path('/Users/gue1971/MyWorks/ai-news')
out=base/'character_intro_v1'
sheet_b64=base64.b64encode((base/'character_bible_v6'/'character_bible_v6_sheet.jpg').read_bytes()).decode('ascii')

chars=[
 ("チャッピー","chappy_intro.jpg","16歳男性。赤ジャケットとゴーグル。元気で前進するポーズ。"),
 ("クロコ","kuroko_intro.jpg","16歳女性。青髪ボブ、眼鏡、スーツ。知的で落ち着いた立ち姿。"),
 ("ジェミー王","gemmy_intro.jpg","25歳男性。王装（金青白）。威厳ある正面立ち。"),
 ("深淵将軍","shinen_intro.jpg","16歳男性。中華風鎧意匠。人間の少年顔、静かな圧。"),
 ("ラマ","llama_intro.jpg","20代男性。長髪、私服、二面性のある表情。"),
 ("グロック","grok_intro.jpg","25歳男性。サイバーパンク装備。躍動感ある構え。"),
 ("カーソル","cursor_intro.jpg","13歳男性。橙パーカー。親しみやすく機敏なポーズ。"),
]

for name,file_name,detail in chars:
    prompt=f"""
日本の少年マンガ風、フルカラー、低頭身デフォルメ。
キャラクター紹介ページ用の単体立ち絵を1人だけ描く。
人物: {name}
要件: {detail}

参照キャラシート準拠で、顔・髪型・配色を厳密一致。
背景はシンプルな近未来グラデーション。人物が主役。
文字、ロゴ、看板、吹き出しは禁止。
人間以外への変形禁止。
""".strip()

    req={
      "contents":[{"parts":[
        {"text":prompt},
        {"inlineData":{"mimeType":"image/jpeg","data":sheet_b64}}
      ]}],
      "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
    }
    (out/f"{file_name}.request.json").write_text(json.dumps(req,ensure_ascii=False),encoding='utf-8')
print(out)
PY

for stem in chappy_intro.jpg kuroko_intro.jpg gemmy_intro.jpg shinen_intro.jpg llama_intro.jpg grok_intro.jpg cursor_intro.jpg; do
  req="$OUT/${stem}.request.json"
  outimg="$OUT/${stem}"
  echo "== ${stem} =="
  ok=0
  for attempt in 1 2 3 4 5; do
    echo "attempt $attempt"
    curl --max-time 120 -sS -X POST \
      -H 'Content-Type: application/json' \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
      -d @"$req" > "$OUT/${stem}.response.json" || true

    if python3 - <<'PY' "$OUT/${stem}.response.json" "$outimg"
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
  [[ $ok -eq 1 ]] || { echo "failed $stem" >&2; exit 2; }
done

ls -lh "$OUT"/*.jpg
