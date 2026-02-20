#!/bin/zsh
set -euo pipefail

API_KEY="${NANOBANANA_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  echo "NANOBANANA_API_KEY is required" >&2
  exit 1
fi

OUT_JSON="/Users/gue1971/MyWorks/ai-news/nanobanana_response.json"
OUT_PNG="/Users/gue1971/MyWorks/ai-news/nanobanana_7chars_3variants.png"

PROMPT=$(cat <<'EOF'
Create a single Japanese shonen manga-style character lineup sheet (portrait orientation 3:4), clean white background.
Style blend: (1) high-energy battle manga linework + speed accents, and (4) playful exaggerated chibi-comedy expressions.

Need exactly 7 characters, each with 3 visual variants (A/B/C) shown side-by-side in one image.
Total 21 mini-panels arranged in a readable grid with labels.

Characters (fictional, no real people):
1) Chappy - unstable genius hero, hopeful but under pressure.
2) Kuroko - quiet elite coder, calm and precise.
3) Gemmy Emperor - overwhelming ecosystem monarch, elegant and dominant.
4) Shin'en General - mysterious strategist from Shin nation, alien strength aura.
5) Llama - dual-faced trickster strategist, half-serious half-joking.
6) Grok - cyberpunk anarchic prodigy, neon and extreme confidence.
7) Cursor Boy - promising side character, bridge between Kuroko and Gemmy.

Design constraints:
- Japanese manga look, black ink + limited accent colors.
- Each character appears in 3 variants: A = serious battle mode, B = comedic deformed mode, C = signature pose mode.
- Add clear romanized name labels and A/B/C markers.
- Keep composition clean and easy to compare for selection.
- No logos, no copyrighted franchise elements, no real persons.
EOF
)

cat > /tmp/nanobanana_request.json <<JSON
{
  "contents": [{"parts": [{"text": $(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))') }]}],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
JSON

curl -sS -X POST \
  -H 'Content-Type: application/json' \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
  -d @/tmp/nanobanana_request.json > "$OUT_JSON"

# extract first inline image
python3 - <<'PY'
import json,base64,sys
resp_path='/Users/gue1971/MyWorks/ai-news/nanobanana_response.json'
out_png='/Users/gue1971/MyWorks/ai-news/nanobanana_7chars_3variants.png'
with open(resp_path,'r',encoding='utf-8') as f:
    data=json.load(f)
img=None
for cand in data.get('candidates',[]):
    content=cand.get('content',{})
    for part in content.get('parts',[]):
        inline=part.get('inlineData') or part.get('inline_data')
        if inline and inline.get('data'):
            img=inline['data']
            break
    if img:
        break
if not img:
    print('No image found in response')
    print(data)
    sys.exit(2)
with open(out_png,'wb') as f:
    f.write(base64.b64decode(img))
print(out_png)
PY
