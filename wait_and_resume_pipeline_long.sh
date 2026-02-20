#!/bin/zsh
set -euo pipefail
API_KEY="${NANOBANANA_API_KEY:-}"
[[ -n "$API_KEY" ]] || { echo "NANOBANANA_API_KEY is required" >&2; exit 1; }
BASE='/Users/gue1971/MyWorks/ai-news'
TEST_REQ="$BASE/test_slides_v2/slide_1.request.json"
[[ -f "$TEST_REQ" ]] || { echo "missing $TEST_REQ" >&2; exit 2; }
STEP6_FLAG_FILE="${STEP6_FLAG_FILE:-$BASE/.step6_approved}"
QA_FLAG_FILE="${QA_FLAG_FILE:-$BASE/.step5_quality_passed}"

CHECK_INTERVAL_SEC=600  # 10 minutes
MAX_ATTEMPTS=144        # up to 24 hours

echo "[monitor] started at $(date '+%Y-%m-%d %H:%M:%S')"
for i in $(seq 1 $MAX_ATTEMPTS); do
  echo "[monitor] health check attempt $i at $(date '+%Y-%m-%d %H:%M:%S')"
  curl --max-time 30 -sS -X POST \
    -H 'Content-Type: application/json' \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}" \
    -d @"$TEST_REQ" > /tmp/nanobanana_health_long.json || true

  if python3 - <<'PY'
import json
p='/tmp/nanobanana_health_long.json'
try:
    data=json.load(open(p,encoding='utf-8'))
except Exception:
    raise SystemExit(2)
if 'error' in data:
    print('[monitor] unavailable', data['error'].get('code'), data['error'].get('status'))
    raise SystemExit(3)
print('[monitor] API looks available')
PY
  then
    echo "[monitor] running step5 at $(date '+%Y-%m-%d %H:%M:%S')"
    NANOBANANA_API_KEY="$API_KEY" "$BASE/retry_generate_test_slides_v2.sh"

    if [[ -f "$QA_FLAG_FILE" && -f "$STEP6_FLAG_FILE" ]]; then
      echo "[monitor] step6 gate passed: $QA_FLAG_FILE + $STEP6_FLAG_FILE"
      echo "[monitor] running step6 at $(date '+%Y-%m-%d %H:%M:%S')"
      NANOBANANA_API_KEY="$API_KEY" "$BASE/generate_full_slides_v1.sh"
      rm -f "$STEP6_FLAG_FILE"
      rm -f "$QA_FLAG_FILE"
    else
      echo "[monitor] step6 blocked: quality gate is not approved"
      echo "[monitor] required quality flag: $QA_FLAG_FILE"
      echo "[monitor] required run flag: $STEP6_FLAG_FILE"
      echo "[monitor] exiting after step5 for manual review"
      exit 10
    fi

    echo "[monitor] pipeline done at $(date '+%Y-%m-%d %H:%M:%S')"
    exit 0
  fi

  echo "[monitor] sleeping ${CHECK_INTERVAL_SEC}s"
  sleep "$CHECK_INTERVAL_SEC"
done

echo "[monitor] max attempts reached without recovery"
exit 4
