#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
TEST_REQ="$BASE/test_slides_v2/slide_1.request.json"
[[ -f "$TEST_REQ" ]] || { echo "missing $TEST_REQ" >&2; exit 2; }
STEP6_FLAG_FILE="${STEP6_FLAG_FILE:-$BASE/.step6_approved}"
QA_FLAG_FILE="${QA_FLAG_FILE:-$BASE/.step5_quality_passed}"

echo 'waiting for API recovery...'
for i in $(seq 1 60); do
  echo "health check attempt $i"
  curl --max-time 20 -sS -X POST -H 'Content-Type: application/json' \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
    -d @"$TEST_REQ" > /tmp/nanobanana_health.json || true

  if python3 - <<'PY'
import json
p='/tmp/nanobanana_health.json'
try:
  data=json.load(open(p,encoding='utf-8'))
except Exception:
  raise SystemExit(2)
if 'error' in data:
  code=data['error'].get('code')
  status=data['error'].get('status')
  print('still unavailable',code,status)
  raise SystemExit(3)
print('api looks available')
PY
  then
    break
  fi
  sleep 20
done

echo 'run step5 (test slides)...'
NANOBANANA_API_KEY="$API_KEY" "$BASE/retry_generate_test_slides_v2.sh"

if [[ ! -f "$QA_FLAG_FILE" || ! -f "$STEP6_FLAG_FILE" ]]; then
  echo "step6 blocked: quality gate is not approved"
  echo "required quality flag: $QA_FLAG_FILE"
  echo "required run flag: $STEP6_FLAG_FILE"
  exit 10
fi

echo 'run step6 (full 18 slides)...'
NANOBANANA_API_KEY="$API_KEY" "$BASE/generate_full_slides_v1.sh"
rm -f "$STEP6_FLAG_FILE"
rm -f "$QA_FLAG_FILE"

echo 'pipeline done'
