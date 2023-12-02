#!/bin/sh
# set -eo pipefail

echo "-> [create.sh]"

# Make sure this script only repply on an Acorn creation event
if [ "${ACORN_EVENT}" != "create" ]; then
   echo "ACORN_EVENT must be [create], currently is [${ACORN_EVENT}]"
   exit 0
fi

########################
### Helper functions ###
########################

# Get the type of a given subscription
get_subscription_type() {
  subId="$1"

  # Get fixed subscription with the provided id
  res=$(curl -sX GET -H "x-api-key: ${ACCOUNT_KEY}" -H "x-api-secret-key: ${SECRET_KEY}" ${API_URL}/fixed/subscriptions/$subId | jq  -r '.status')
  if [ "$res" = "active" ]; then
    echo "fixed"
  else
    # Get flexible subscription with the provided id
    res=$(curl -sX GET -H "x-api-key: ${ACCOUNT_KEY}" -H "x-api-secret-key: ${SECRET_KEY}" ${API_URL}/flexible/subscriptions/$subId | jq -r '.status')
    if [ "$res" = "active" ]; then
      echo "flexible"
    else
      echo "invalid"
    fi
  fi
}

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
  echo "... current status [${state}]"
  echo "... error: $(echo $t | jq .response.error.description)"

  if [ "$state" = "processing-error" ]; then
      exit 0
  fi

  if [ "$state" != "processing-completed" ]; then
      return 1
  fi

  return 0
}

check_redis() {
  host="$1"
  port="$2"
  res=$(redis-cli -u redis://default:${DB_PASS}@${host}:${port} ping 2>/dev/null)
  echo $res
  if [ "$res" = "PONG" ]; then
    return 0
  else
    return 1
  fi
}

########################
###  Creation logic  ###
########################

# If no subscription is provided, one will be created using those values
# (will be used as service configuration in next versions)
PLAN_TYPE="fixed"
PLAN_NAME="Standard 30MB"

# Internal subscription related variables
planType=${PLAN_TYPE}
subscriptionId=${SUBSCRIPTION_ID}

# Keep track of the subscription id is created alongside the database
internalSubscription=""

# Retrieve subscription if id provided or create a new one
if [[ "${subscriptionId}" != "" ]]; then
  # Get the subscription's type
  type=$(get_subscription_type ${subscriptionId})
  if [ "$type" != "invalid" ]; then
    planType=$type
  else
    echo "-> provided subscription id [${subscriptionId}] is invalid"
    exit 1
  fi
  echo "-> subscription [${subscriptionId}] of type [${planType}] provided"
else
  # Get list of available plans
  echo "-> about to get list of available plans"
  plans=$(curl -sX GET \
    -H "x-api-key: ${ACCOUNT_KEY}" \
    -H "x-api-secret-key: ${SECRET_KEY}" \
    ${API_URL}/${planType}/plans)

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
  echo "-> about to create a subscription"
  task=$(curl -sX POST \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${ACCOUNT_KEY}" \
    -H "x-api-secret-key: ${SECRET_KEY}" \
    -d "{
      \"name\": \"Acorn subscription\",
      \"planId\": $planId
    }" \
    ${API_URL}/${planType}/subscriptions)
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
  internalSubscription=$subscriptionId
  echo "-> subscription [${subscriptionId}] of type [${planType}] created"
fi

# Create a database
echo "-> about to create a database"
task=$(curl -sX POST \
  -H "content-type: application/json" \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  -d "{ \"name\": \"$DB_NAME\",
        \"password\": \"$DB_PASS\" }" \
  ${API_URL}/${planType}/subscriptions/${subscriptionId}/databases)
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
echo "-> waiting for publicEndpoint property to be there"
while true; do
  databaseInfo=$(curl -sX GET \
    -H "x-api-key: ${ACCOUNT_KEY}" \
    -H "x-api-secret-key: ${SECRET_KEY}" \
    ${API_URL}/${planType}/subscriptions/${subscriptionId}/databases/${databaseId})

  # Get publicEndpoint property if there
  publicEndpoint=$(echo "$databaseInfo" | grep -o '"publicEndpoint" : "[^"]*"' | cut -d'"' -f4)

  # Check if "publicEndpoint" is empty or not present
  if [ "$publicEndpoint" != "" ]; then
      break
  fi
  sleep 2
  echo "... retrying in 2 seconds"
done
echo "-> publicEndpoint property is there"

# Get database information to be used in the Acorn Service
dbHost=$(echo $publicEndpoint | cut -d':' -f1)
dbPort=$(echo $publicEndpoint | cut -d':' -f2)
echo "-> retrieved Host:[$dbHost] / Port:[$dbPort]"

# Wait for Redis database to be reachable
# (might need a few tens of seconds)
echo "-> waiting for Redis to become available"
while ! check_redis $dbHost $dbPort; do
    sleep 5
    echo "... retrying in 5 seconds"
done
echo "-> redis database is available"

cat > /run/secrets/output<<EOF
services: redis: {
  address: "${dbHost}"
  secrets: ["admin"]
  data: {
    dbName: "${DB_NAME}"
    port: "${dbPort}"
  }
}
secrets: resources: {
  data: {
    subscription_id: "${internalSubscription}"
    database_id: "${databaseId}"
  }
}
EOF