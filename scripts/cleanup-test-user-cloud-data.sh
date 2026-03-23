#!/bin/bash
# Deletes pre-production Just Vault cloud data for a single test user.

set -euo pipefail

PROFILE="${PROFILE:-just-vault}"
REGION="${REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-JustVault}"
BUCKET_NAME="${BUCKET_NAME:-just-vault-prod-blobs}"
USER_ID="${USER_ID:-}"

if [ -z "$USER_ID" ]; then
  echo "USER_ID is required."
  echo "Example:"
  echo "  USER_ID='us-east-1:example-id' bash scripts/cleanup-test-user-cloud-data.sh"
  exit 1
fi

echo "Cleaning cloud data for test user: $USER_ID"

PK="USER#$USER_ID"
export PROFILE REGION TABLE_NAME

echo "1. Querying DynamoDB items..."
ITEMS_JSON=$(aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression "PK = :pk" \
  --expression-attribute-values "{\":pk\":{\"S\":\"$PK\"}}" \
  --profile "$PROFILE" \
  --region "$REGION")

COUNT=$(echo "$ITEMS_JSON" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("Items", [])))')
echo "Found $COUNT DynamoDB items"

if [ "$COUNT" -gt 0 ]; then
  echo "$ITEMS_JSON" | python3 - <<'PY'
import json,sys,subprocess,tempfile,os
data=json.load(sys.stdin)
items=data.get("Items", [])
requests=[]
for item in items:
    requests.append({
        "DeleteRequest": {
            "Key": {
                "PK": item["PK"],
                "SK": item["SK"]
            }
        }
    })

table=os.environ.get("TABLE_NAME", "JustVault")
for i in range(0, len(requests), 25):
    batch={"RequestItems": {table: requests[i:i+25]}}
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json") as f:
        json.dump(batch, f)
        path=f.name
    try:
        subprocess.check_call([
            "aws", "dynamodb", "batch-write-item",
            "--request-items", f"file://{path}",
            "--profile", os.environ["PROFILE"],
            "--region", os.environ["REGION"]
        ])
    finally:
        os.unlink(path)
PY
else
  echo "No DynamoDB items to delete"
fi

echo "2. Deleting S3 prefix..."
aws s3 rm "s3://$BUCKET_NAME/users/$USER_ID/" \
  --recursive \
  --profile "$PROFILE" \
  --region "$REGION" || true

echo
echo "Done."
echo "This script removed cloud-side test data for $USER_ID."
echo "If you also want a clean device state, delete the app from the device/simulator and reinstall."
