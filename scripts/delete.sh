#!/bin/sh
set -eo pipefail

echo "-> [delete.sh][$ACORN_EVENT]"

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

  t=$(curl -sX GET \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  ${API_URL}/tasks/$taskId)

  state=$(echo $t | jq -r .status)

  if [[ "$state" != "processing-completed" ]]; then
      return 1
  fi

  return 0
}

# create task to delete database
echo "-> about to delete database [$DATABASE_ID]"
task=$(curl -sX DELETE \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  ${API_URL}/fixed/subscriptions/${SUBSCRIPTION_ID}/databases/${DATABASE_ID})
taskId=$(echo $task | jq -r .taskId)
echo "-> associated task is [$taskId]"

# Wait for task to complete
while ! check_task "$taskId"; do
  echo "-> waiting for database to be deleted"
  sleep 2
done
echo "-> database deleted"

# Create task to delete subscription
echo "-> about to delete subscription [$SUBSCRIPTION_ID]"
task=$(curl -sX DELETE \
  -H "x-api-key: ${ACCOUNT_KEY}" \
  -H "x-api-secret-key: ${SECRET_KEY}" \
  ${API_URL}/fixed/subscriptions/${SUBSCRIPTION_ID})
taskId=$(echo $task | jq -r .taskId)
echo "-> associated task is [$taskId]"

# Wait for task to complete
while ! check_task "$taskId"; do
  echo "-> waiting for subscription to be deleted"
  sleep 2
done
echo "-> subscription deleted"
