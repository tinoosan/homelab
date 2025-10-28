#!/bin/bash
# aria2 hook script: runs when a download completes
# Arguments passed by aria2:
# $1 = GID (aria2's unique download ID)
# $2 = Number of files
# $3 = File path of the first file

GID="$1"
NUM_FILES="$2"
FILE_PATH="$3"

# n8n webhook URL
WEBHOOK_URL="https://n8n.jamaguchi.xyz/webhook/aria2"

# Optional: log for debugging
LOG_FILE="/var/log/aria2-webhook.log"

{
  echo "[$(date)] Download complete"
  echo "GID: $GID"
  echo "Files: $NUM_FILES"
  echo "File path: $FILE_PATH"
  echo "Sending webhook..."
} >> "$LOG_FILE"

# Send webhook to n8n
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"gid\": \"$GID\", \"file\": \"$FILE_PATH\", \"status\": \"complete\"}" \
  >> "$LOG_FILE" 2>&1

echo "[$(date)] Webhook sent successfully" >> "$LOG_FILE"
exit 0

