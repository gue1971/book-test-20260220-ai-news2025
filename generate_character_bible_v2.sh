#!/bin/zsh
set -euo pipefail

API_KEY="${NANOBANANA_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  echo "NANOBANANA_API_KEY is required" >&2
  exit 1
fi

OUT_DIR="/Users/gue1971/MyWorks/ai-news/character_bible_v2"
mkdir -p "$OUT_DIR"

# name|prompt
cat > "$OUT_DIR/characters.txt" <<'EOF'
chappy|A案固定。日本の少年マンガ風。人間キャラのみ。チャッピーを1人だけ描く。年齢は10代後半〜20代前半の男性。ツンツンの短髪、ゴーグルを額につける、赤いマフラー、機動的ジャケット。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
kuroko|A案固定。日本の少年マンガ風。人間キャラのみ。クロコを1人だけ描く。年齢20代男性。黒髪ショート、細めの目、黒系ミニマルコート、知的で寡黙。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
gemmy|A案固定。日本の少年マンガ風。人間キャラのみ。ジェミー皇を1人だけ描く。中性的で威厳ある若い皇帝、長めの金髪、青と白の重厚な儀礼服、王冠。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
shinen|A案固定。日本の少年マンガ風。人間キャラのみ。深淵将軍を1人だけ描く。年齢30代男性、黒髪、切れ長の目、中華風軍装、静かな威圧。顔が見えること。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
llama|A案固定。日本の少年マンガ風。人間キャラのみ。ラマを1人だけ描く。年齢20代男性、短髪、軽口トリックスター風、カジュアル+戦略家の服。二面性の雰囲気。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
grok|A案固定。日本の少年マンガ風。人間キャラのみ。グロックを1人だけ描く。年齢20代男性、サイバーパンク要素（ネオンアクセサリやイヤーピース）、鋭い目つき。ロボット化しない。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
cursor|A案固定。日本の少年マンガ風。人間キャラのみ。カーソル少年を1人だけ描く。10代後半の男子、素直で成長中、シンプルなフーディ。5カット構成: 正面バスト、横顔バスト、真剣顔、デフォルメ笑顔、怒り顔。白背景。文字は入れない。
EOF

while IFS='|' read -r name prompt; do
  req="$OUT_DIR/${name}.json"
  img="$OUT_DIR/${name}.jpg"

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

  curl -sS -X POST \
    -H 'Content-Type: application/json' \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
    -d @"$req" > "$OUT_DIR/${name}_resp.json"

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
    print('No image in', resp)
    print(data)
    sys.exit(2)
with open(out,'wb') as f:
    f.write(base64.b64decode(img))
print(out)
PY

done < "$OUT_DIR/characters.txt"

python3 - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
base=Path('/Users/gue1971/MyWorks/ai-news/character_bible_v2')
order=['chappy','kuroko','gemmy','shinen','llama','grok','cursor']
imgs=[]
for n in order:
    im=Image.open(base/f'{n}.jpg').convert('RGB')
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
