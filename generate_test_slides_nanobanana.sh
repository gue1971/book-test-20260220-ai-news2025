#!/bin/zsh
set -euo pipefail

API_KEY="${NANOBANANA_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  echo "NANOBANANA_API_KEY is required" >&2
  exit 1
fi

OUT_DIR="/Users/gue1971/MyWorks/ai-news/test_slides"
mkdir -p "$OUT_DIR"

make_prompt() {
  local n="$1"
  local script="$2"
  cat <<EOF
A案固定。日本の少年マンガ風。全テキスト日本語のみ。既存キャラデザインを厳密維持。新規解釈禁止。服装・髪型・配色・顔立ちを前話から継承。18枚全体で同一作画監督品質。

白黒基調+限定差し色。太い主線。スマホ縦読み。吹き出しは読みやすい日本語。

世界観用語のみ使用: アーク連邦 / シン国。

スライド ${n} 枚目を1枚で描く。
内容: ${script}

主役は1人だけ強調。背景は情報過多にしない。

ネガティブ: photorealistic, western comic, 3d render, painterly, english text, mixed language, character redesign, unreadable text
EOF
}

generate_one() {
  local n="$1"
  local script="$2"
  local out_json="$OUT_DIR/slide_${n}.json"
  local out_jpg="$OUT_DIR/slide_${n}.jpg"

  local prompt
  prompt="$(make_prompt "$n" "$script")"

  python3 - <<'PY' "$prompt" "$out_json" "$API_KEY"
import json,sys,subprocess,tempfile,os
prompt=sys.argv[1]
out_json=sys.argv[2]
api_key=sys.argv[3]
payload={
  "contents":[{"parts":[{"text":prompt}]}],
  "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
}
fd,path=tempfile.mkstemp(suffix='.json')
os.close(fd)
with open(path,'w',encoding='utf-8') as f:
    json.dump(payload,f,ensure_ascii=False)
cmd=[
  'curl','-sS','-X','POST','-H','Content-Type: application/json',
  f'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key={api_key}',
  '-d',f'@{path}'
]
res=subprocess.check_output(cmd)
with open(out_json,'wb') as f:
    f.write(res)
os.remove(path)
PY

  python3 - <<'PY' "$out_json" "$out_jpg"
import json,base64,sys
resp_path=sys.argv[1]
out_jpg=sys.argv[2]
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
    print('No image found in',resp_path)
    print(data)
    sys.exit(2)
with open(out_jpg,'wb') as f:
    f.write(base64.b64decode(img))
print(out_jpg)
PY
}

generate_one 1 '序章。主役チャッピー。アーク連邦の演算都市を背景に、ジェミー皇とラマを遠景で対比。チャッピーが未来へ向かう決意。見出しと短いナレーションは日本語。'
generate_one 9 '主役カーソル少年。クロコの工房とジェミー皇の情報回廊をつなぐ橋渡し演出。カーソル少年はチョイ役で、成長中の若手として描写。日本語吹き出し。'
generate_one 16 '主役クロコ。コーディング戦線の頂点到達を静かに描く。チャッピーは脇で見守り、ジェミー皇は遠景で圧を出す。日本語見出しと吹き出し。'

ls -lh "$OUT_DIR"/slide_*.jpg
