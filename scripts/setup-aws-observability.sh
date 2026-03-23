#!/bin/bash
# setup-aws-observability.sh
# Provisions an AWS-native dashboard, alerts, and budgets for Just Vault.

set -euo pipefail

PROFILE="${PROFILE:-just-vault}"
REGION="${REGION:-us-east-1}"
BUCKET_NAME="${BUCKET_NAME:-just-vault-prod-blobs}"
TABLE_NAME="${TABLE_NAME:-JustVault}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

DASHBOARD_NAME="${DASHBOARD_NAME:-JustVault-Operations}"
SNS_TOPIC_NAME="${SNS_TOPIC_NAME:-JustVaultOpsAlerts}"
S3_METRICS_ID="${S3_METRICS_ID:-EntireBucket}"

TOTAL_MONTHLY_BUDGET_USD="${TOTAL_MONTHLY_BUDGET_USD:-50}"
S3_MONTHLY_BUDGET_USD="${S3_MONTHLY_BUDGET_USD:-20}"
DYNAMODB_MONTHLY_BUDGET_USD="${DYNAMODB_MONTHLY_BUDGET_USD:-10}"
CLOUDWATCH_MONTHLY_BUDGET_USD="${CLOUDWATCH_MONTHLY_BUDGET_USD:-5}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

create_budget_if_missing() {
  local budget_name="$1"
  local amount="$2"
  local service_name="${3:-}"

  if aws budgets describe-budget \
    --account-id "$ACCOUNT_ID" \
    --budget-name "$budget_name" \
    --profile "$PROFILE" >/dev/null 2>&1; then
    echo "Budget already exists: $budget_name"
    return
  fi

  local budget_json
  if [ -n "$service_name" ]; then
    budget_json=$(cat <<EOF
{
  "BudgetName": "$budget_name",
  "BudgetLimit": { "Amount": "$amount", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "Service": ["$service_name"]
  }
}
EOF
)
  else
    budget_json=$(cat <<EOF
{
  "BudgetName": "$budget_name",
  "BudgetLimit": { "Amount": "$amount", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF
)
  fi

  local notifications_json
  notifications_json=$(cat <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$ALERT_EMAIL"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$ALERT_EMAIL"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$ALERT_EMAIL"
      }
    ]
  }
]
EOF
)

  echo "Creating budget: $budget_name"
  aws budgets create-budget \
    --account-id "$ACCOUNT_ID" \
    --budget "$budget_json" \
    --notifications-with-subscribers "$notifications_json" \
    --profile "$PROFILE"
}

put_alarm() {
  aws cloudwatch put-metric-alarm "$@" --profile "$PROFILE"
}

require_command aws

if [ -z "$ALERT_EMAIL" ]; then
  echo "ALERT_EMAIL is required."
  echo "Example:"
  echo "  ALERT_EMAIL=you@example.com bash scripts/setup-aws-observability.sh"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE")

echo "Using account: $ACCOUNT_ID"
echo "Using profile: $PROFILE"
echo "Using region:  $REGION"

echo
echo "1. Creating SNS topic for CloudWatch alarms..."
TOPIC_ARN=$(aws sns create-topic \
  --name "$SNS_TOPIC_NAME" \
  --query TopicArn \
  --output text \
  --profile "$PROFILE")

aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$ALERT_EMAIL" \
  --profile "$PROFILE" >/dev/null || true

echo "SNS topic: $TOPIC_ARN"
echo "Check your email and confirm the SNS subscription."

echo
echo "2. Enabling S3 request metrics on the bucket..."
aws s3api put-bucket-metrics-configuration \
  --bucket "$BUCKET_NAME" \
  --id "$S3_METRICS_ID" \
  --metrics-configuration "{\"Id\":\"$S3_METRICS_ID\"}" \
  --profile "$PROFILE"

echo
echo "3. Creating CloudWatch dashboard..."
cat >/tmp/just-vault-dashboard.json <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Estimated AWS Spend (USD)",
        "view": "timeSeries",
        "stat": "Maximum",
        "period": 21600,
        "region": "us-east-1",
        "metrics": [
          [ "AWS/Billing", "EstimatedCharges", "Currency", "USD", { "label": "Total" } ],
          [ ".", ".", ".", ".", "ServiceName", "Amazon Simple Storage Service", { "label": "S3" } ],
          [ ".", ".", ".", ".", "ServiceName", "Amazon DynamoDB", { "label": "DynamoDB" } ],
          [ ".", ".", ".", ".", "ServiceName", "AmazonCloudWatch", { "label": "CloudWatch" } ],
          [ ".", ".", ".", ".", "ServiceName", "Amazon Cognito", { "label": "Cognito" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "S3 Request Volume",
        "view": "timeSeries",
        "stat": "Sum",
        "period": 300,
        "region": "$REGION",
        "metrics": [
          [ "AWS/S3", "AllRequests", "BucketName", "$BUCKET_NAME", "FilterId", "$S3_METRICS_ID", { "label": "All Requests" } ],
          [ ".", "PutRequests", ".", ".", ".", ".", { "label": "PUT" } ],
          [ ".", "GetRequests", ".", ".", ".", ".", { "label": "GET" } ],
          [ ".", "BytesUploaded", ".", ".", ".", ".", { "label": "Bytes Uploaded", "yAxis": "right" } ],
          [ ".", "BytesDownloaded", ".", ".", ".", ".", { "label": "Bytes Downloaded", "yAxis": "right" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "S3 Errors",
        "view": "timeSeries",
        "stat": "Sum",
        "period": 300,
        "region": "$REGION",
        "metrics": [
          [ "AWS/S3", "4xxErrors", "BucketName", "$BUCKET_NAME", "FilterId", "$S3_METRICS_ID", { "label": "4xx Errors" } ],
          [ ".", "5xxErrors", ".", ".", ".", ".", { "label": "5xx Errors" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "DynamoDB Health",
        "view": "timeSeries",
        "stat": "Sum",
        "period": 300,
        "region": "$REGION",
        "metrics": [
          [ "AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "$TABLE_NAME", { "label": "Read Capacity" } ],
          [ ".", "ConsumedWriteCapacityUnits", ".", ".", { "label": "Write Capacity" } ],
          [ ".", "ThrottledRequests", ".", ".", { "label": "Throttled Requests" } ],
          [ ".", "SystemErrors", ".", ".", { "label": "System Errors" } ],
          [ ".", "UserErrors", ".", ".", { "label": "User Errors" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "DynamoDB Latency (P95)",
        "view": "timeSeries",
        "stat": "p95",
        "period": 300,
        "region": "$REGION",
        "metrics": [
          [ "AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "$TABLE_NAME", "Operation", "PutItem", { "label": "PutItem" } ],
          [ ".", ".", ".", ".", "Operation", "GetItem", { "label": "GetItem" } ],
          [ ".", ".", ".", ".", "Operation", "Query", { "label": "Query" } ]
        ]
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body file:///tmp/just-vault-dashboard.json \
  --profile "$PROFILE"

echo
echo "4. Creating CloudWatch alarms..."

put_alarm \
  --alarm-name "JustVault-Billing-Total-EstimatedCharges" \
  --alarm-description "Estimated AWS charges exceeded threshold" \
  --namespace AWS/Billing \
  --metric-name EstimatedCharges \
  --dimensions Name=Currency,Value=USD \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold "$TOTAL_MONTHLY_BUDGET_USD" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region us-east-1

put_alarm \
  --alarm-name "JustVault-S3-5xxErrors" \
  --alarm-description "S3 5xx errors detected" \
  --namespace AWS/S3 \
  --metric-name 5xxErrors \
  --dimensions Name=BucketName,Value="$BUCKET_NAME" Name=FilterId,Value="$S3_METRICS_ID" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

put_alarm \
  --alarm-name "JustVault-S3-4xxErrors-High" \
  --alarm-description "High rate of S3 4xx errors" \
  --namespace AWS/S3 \
  --metric-name 4xxErrors \
  --dimensions Name=BucketName,Value="$BUCKET_NAME" Name=FilterId,Value="$S3_METRICS_ID" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 3 \
  --threshold 25 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

put_alarm \
  --alarm-name "JustVault-DynamoDB-ThrottledRequests" \
  --alarm-description "DynamoDB throttling detected" \
  --namespace AWS/DynamoDB \
  --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value="$TABLE_NAME" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

put_alarm \
  --alarm-name "JustVault-DynamoDB-SystemErrors" \
  --alarm-description "DynamoDB system errors detected" \
  --namespace AWS/DynamoDB \
  --metric-name SystemErrors \
  --dimensions Name=TableName,Value="$TABLE_NAME" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

echo
echo "5. Creating AWS Budgets..."
create_budget_if_missing "JustVault-Total-Monthly" "$TOTAL_MONTHLY_BUDGET_USD"
create_budget_if_missing "JustVault-S3-Monthly" "$S3_MONTHLY_BUDGET_USD" "Amazon Simple Storage Service"
create_budget_if_missing "JustVault-DynamoDB-Monthly" "$DYNAMODB_MONTHLY_BUDGET_USD" "Amazon DynamoDB"
create_budget_if_missing "JustVault-CloudWatch-Monthly" "$CLOUDWATCH_MONTHLY_BUDGET_USD" "AmazonCloudWatch"

echo
echo "Done."
echo "Dashboard: CloudWatch > Dashboards > $DASHBOARD_NAME"
echo "SNS topic: $TOPIC_ARN"
echo
echo "Important:"
echo "- Billing metrics are not true real-time; expect a delay of several hours."
echo "- S3 request metrics and DynamoDB metrics are near real-time and should catch spikes quickly."
echo "- If billing alarms do not fire, enable CloudWatch billing alerts in the AWS Billing console first."
