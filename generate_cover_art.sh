#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
OUT="$BASE/cover_art"
mkdir -p "$OUT"

python3 - <<'PY'
import base64, json, pathlib
base=pathlib.Path('/Users/gue1971/MyWorks/ai-news')
out=base/'cover_art'
sheet=(base/'character_bible_v6'/'character_bible_v6_sheet.jpg').read_bytes()
sheet_b64=base64.b64encode(sheet).decode('ascii')
char_files=[
 ('chappy','chappy.jpg'),
 ('kuroko','kuroko.jpg'),
 ('gemmy','gemmy.jpg'),
 ('shinen','shinen.jpg'),
 ('llama','llama.jpg'),
 ('grok','grok.jpg'),
 ('cursor','cursor.jpg'),
]
char_refs=[]
for _,fn in char_files:
    b=(base/'character_bible_v6'/fn).read_bytes()
    char_refs.append(base64.b64encode(b).decode('ascii'))

prompt='''
日本の少年マンガ風、フルカラー、低頭身デフォルメ寄り。cover_art_v6の雰囲気を維持した表紙用の縦長1枚絵（スマホ9:16）。
文字は絶対に入れない（タイトル・ロゴ・英字・看板文字すべて禁止）。
1枚の連続したイラストのみ。漫画コマ割り・分割画面・白帯余白・枠線は禁止。
全画面を絵で埋める（上下左右に余白なし）。

世界観:
- 近未来のAI都市「アーク連邦」の夜景
- キャラ配置は3段で固定（上→中→下）:
  上段: 深淵将軍（左上寄り） / ラマ（右上）
  中段: ジェミー王（左） / チャッピー（中央） / クロコ（右）
  下段: グロック（左下, 上半身大きめ） / カーソル（右下, 全身）
- 位置ごとの人物固定:
  上左=深淵将軍、上右=ラマ、
  中左=ジェミー王、中央=チャッピー、中右=クロコ、
  下左=グロック、下右=カーソル
- クロコは「青髪ボブ＋眼鏡＋女性スーツ」で明確に識別できること
- チャッピーは中央で前進ポーズ（腕上げ歓喜ポーズ禁止）
- 中段3人はcover_art_v6より少し上に配置
- 深淵将軍は少し左に寄せる
- カーソルは小人化禁止（クロコと比較して不自然に小さくしない）
- グロックの前景サイズ感はcover_art_v6の強さを維持
- 深淵将軍は必ず人間の少年顔。仮面・ロボ鎧・機械化は禁止
- 7人全員が見切れずに入る、縦長レイアウト
- 各キャラは必ず1回だけ登場（重複禁止）
- 7キャラ以外の人物を追加しない
- 必須登場（各1回）: チャッピー、クロコ、ジェミー王、深淵将軍、ラマ、グロック、カーソル
- 重複禁止: カーソルは1体のみ
- 重複禁止: 深淵将軍は1体のみ
- 各キャラ頭上に、後から名前を重ねるための小さな余白を残す
- 余白は背景だけを空ける。白いラベル枠・吹き出し・プレートは絶対に描かない
- 白矩形、白カード、空欄ボックスは絶対禁止
- 参照画像どおりの人物対応を維持し、キャラを入れ替えない
- ラマは長髪で私服系。深淵将軍は16歳の少年顔＋中華風鎧意匠

品質要件:
- 参照キャラシートに厳密準拠（顔・髪型・配色・年齢感）
- 全員人間。動物化・怪物化・ロボ化禁止
- 画面上部18%はタイトル重ね用に情報量を減らす（空ける）
- キャラ配置に合わせて背景の遠近・光源・動線を再構成し、動きのある一体感を作る
- 画像内テキスト禁止
'''.strip()

parts=[{"text":prompt},{"inlineData":{"mimeType":"image/jpeg","data":sheet_b64}}]
for b64 in char_refs:
  parts.append({"inlineData":{"mimeType":"image/jpeg","data":b64}})

req={
  "contents":[{"parts":parts}],
  "generationConfig":{"responseModalities":["TEXT","IMAGE"]}
}
(out/'cover.request.json').write_text(json.dumps(req,ensure_ascii=False),encoding='utf-8')
print(out/'cover.request.json')
PY

ok=0
for attempt in 1 2 3 4 5 6; do
  echo "cover attempt $attempt"
  curl --max-time 120 -sS -X POST \
    -H 'Content-Type: application/json' \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
    -d @"$OUT/cover.request.json" > "$OUT/cover.response.json" || true

  if python3 - <<'PY' "$OUT/cover.response.json" "$OUT/cover_art_v10.jpg"
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
  sleep 5
done

[[ $ok -eq 1 ]] || { echo 'cover generation failed' >&2; exit 2; }
ls -lh "$OUT"/cover_art_v10.jpg
