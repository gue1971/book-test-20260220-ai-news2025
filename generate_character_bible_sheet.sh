#!/bin/zsh
set -euo pipefail

API_KEY="${NANOBANANA_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  echo "NANOBANANA_API_KEY is required" >&2
  exit 1
fi

OUT_JSON="/Users/gue1971/MyWorks/ai-news/character_bible_response.json"
OUT_JPG="/Users/gue1971/MyWorks/ai-news/character_bible_A_lock.jpg"

PROMPT='A案固定。日本の少年マンガ風。全テキスト日本語のみ。既存キャラデザインを厳密維持。新規解釈禁止。\n\n縦長1枚のキャラ確定シートを作成。7キャラそれぞれについて、正面バスト、横顔バスト、表情3種（真剣/デフォルメ笑顔/怒り）を並べる。\n\nキャラ: チャッピー、クロコ、ジェミー皇、深淵将軍、ラマ、グロック、カーソル少年。\n\nデザイン方針: 熱血バトル少年マンガ + デフォルメ。太い主線、見やすい白背景、限定アクセント色。\n\n必須: 各キャラ名ラベルは日本語のみ。A案固定のためB/C表記は不要。比較しやすい整然グリッド。\n\n禁止: 英語文字、実在人物、既存版権キャラ、画風混在。'

cat > /tmp/character_bible_request.json <<JSON
{
  "contents": [{"parts": [{"text": "$PROMPT"}]}],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
JSON

curl -sS -X POST \
  -H 'Content-Type: application/json' \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
  -d @/tmp/character_bible_request.json > "$OUT_JSON"

python3 - <<'PY'
import json,base64,sys
resp_path='/Users/gue1971/MyWorks/ai-news/character_bible_response.json'
out_jpg='/Users/gue1971/MyWorks/ai-news/character_bible_A_lock.jpg'
with open(resp_path,'r',encoding='utf-8') as f:
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
    print('No image found')
    print(data)
    sys.exit(2)
with open(out_jpg,'wb') as f:
    f.write(base64.b64decode(img))
print(out_jpg)
PY
