#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
RUN_DIR="${1:-}"
[[ -n "$RUN_DIR" ]] || { echo "Usage: resume_character_intro_pose_pool.sh <run_dir>" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "missing run dir: $RUN_DIR" >&2; exit 3; }

for key in chappy kuroko gemmy shinen llama grok cursor; do
  for pose in pose_a pose_b pose_c; do
    outimg="$RUN_DIR/$key/${pose}.jpg"
    req="$RUN_DIR/$key/${pose}.request.json"
    [[ -f "$req" ]] || continue
    if [[ -f "$outimg" ]]; then
      echo "skip existing $key/$pose"
      continue
    fi
    echo "== ${key}/${pose} =="
    ok=0
    for a in 1 2 3 4 5 6 7 8; do
      echo "attempt $a"
      curl --max-time 120 -sS -X POST -H 'Content-Type: application/json' \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
        -d @"$req" > "$RUN_DIR/$key/${pose}.response.json" || true
      if python3 - <<'PY' "$RUN_DIR/$key/${pose}.response.json" "$outimg"
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
      sleep 4
    done
    [[ $ok -eq 1 ]] || { echo "failed $key/$pose" >&2; exit 2; }
  done
done

echo "completed"
find "$RUN_DIR" -name '*.jpg' | wc -l
