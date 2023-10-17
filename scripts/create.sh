#!/bin/sh
set -eo pipefail

echo "-> will process to resources creation"

# Current limitation in plan selection
PLAN_TYPE="fixed"
PLAN_NAME="Standard 30MB"

# Helper functions
get_task() {
  taskId="$1"

  t=$(curl -sX GET \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  ${API_URL}/tasks/$taskId)

  echo $t
}

check_task() {
  taskId="$1"

  t=$(get_task $taskId)

  state=$(echo $t | jq -r .status)

  if [[ "$state" != "processing-completed" ]]; then
      return 1
  fi

  return 0
}

wait_for_db() {
  echo "to be used to wait for the database public endpoint"
}

check_redis() {
  echo "-> checking redis using ping"
  redis-cli -u redis://default:${DB_PASS}@${DB_HOST}:${DB_PORT} ping 2>/dev/null
}

echo "-> will process to resources creation"

# Get list of available plans
echo "-> about to get list of available plans"
plans=$(curl -sX GET \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  ${API_URL}/${PLAN_TYPE}/plans)

# Get planId from provider, region and name
planId=$(echo $plans | jq \
  --arg region "$REGION" \
  --arg provider "$PROVIDER" \
  --arg plan_name "$PLAN_NAME" \
  '.plans[] | select(.name == $plan_name and .provider == $provider and .region == $region) | .id')
echo "-> selected planId is [$planId]"

# Make sure a plan was retrieved
if [[ "$planId" = "" ]]; then
  echo "-> planId is empty. Aborting..."
  exit 1
fi

# Create a subscription
echo "-> about to create a Redis Cloud subscription"
task=$(curl -sX POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  -d "{
    \"name\": \"My new subscription\",
    \"planId\": $planId
  }" \
  ${API_URL}/${PLAN_TYPE}/subscriptions)
taskId=$(echo $task | jq -r .taskId)
echo "-> associated task is [$taskId]"

# Waiting for subscription task to be completed"
while ! check_task "$taskId"; do
  echo "-> waiting for subscription task to be completed"
  sleep 2
done
echo "-> Subscription task completed"

# Get subscription ID from task
subscriptionId=$(get_task $taskId | jq -r '.response.resourceId')
echo "-> subscriptionId is [$subscriptionId]"

# Create a redis cluster
echo "-> about to create a Redis Cloud database"
task=$(curl -sX POST \
  -H "content-type: application/json" \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  -d "{ \"name\": \"$DB_NAME\",
        \"password\": \"$DB_PASS\" }" \
  ${API_URL}/${PLAN_TYPE}/subscriptions/${subscriptionId}/databases)
taskId=$(echo $task | jq -r .taskId)
echo "-> associated task is [$taskId]"

# Wait for database to be created
while ! check_task "$taskId"; do
  echo "-> waiting for database task to be completed..."
  sleep 2
done
echo "-> database task completed"

# Get database ID from task
databaseId=$(get_task $taskId | jq -r '.response.resourceId')
echo "-> databaseId is [$databaseId]"

# Wait for publicEndpoint to be available
publicEndpoint=""
while true; do
  databaseInfo=$(curl -sX GET \
    -H "x-api-key: ${ACCOUNT_KEY}" \
    -H "x-api-secret-key: ${SECRET_KEY}" \
    ${API_URL}/${PLAN_TYPE}/subscriptions/${subscriptionId}/databases/${databaseId})
  publicEndpoint=$(echo "$databaseInfo" | jq -r '.publicEndpoint')

  # Check if "publicEndpoint" is empty or not present
  if [ -n "$publicEndpoint" ] && [ "$publicEndpoint" != "null" ]; then
      break
  fi
  sleep 2
done

# Get database information to be used in the Acorn Service
DB_HOST=$(echo $publicEndpoint | cut -d':' -f1)
DB_PORT=$(echo $publicEndpoint | cut -d':' -f2)

# Wait for Redis cloud cluster to be reachable
while ! check_redis; do
    echo "-> waiting for Redis to become available"
    sleep 2
done
echo "-> redis database is available"

cat > /run/secrets/output<<EOF
services: redis: {
  address: "${DB_HOST}"
  secrets: ["admin"]
  data: {
    dbName: "${DB_NAME}"
    port: "${DB_PORT}"
  }
}
secrets: resources: {
  data: {
    subscription_id: "${subscriptionId}"
    database_id: "${databaseId}"
  }
}
EOF