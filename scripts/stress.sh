#!/bin/bash

echo "Starting load generator..."
echo "Press [CTRL+C] to stop."

while true; do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST 'https://frontend-tomcat-service-observability-demo.apps.cluster-vjvmn.dynamic.redhatworkshops.io/analyze' \
    -H 'Content-Type: application/json' \
    --data-raw '{"data":"This demo is amazing!"}')

  echo "Request sent. Response Code: $status_code"
done