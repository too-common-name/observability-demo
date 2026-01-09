#!/bin/bash

# ====================================================================================
#  LOAD GENERATOR
#  Usage: ./load-generator.sh <base_url> [task] [count]
#  Tasks: 
#    - analyze (default): Continuous traffic generation
#    - overload_cpu: Triggers parallel CPU burn (Default count: 3)
#    - overload_memory: Triggers Memory leak (Default count: 2, 200MB each)
#    - reset: Clears backend memory
# ====================================================================================

BASE_URL=$1
TASK=${2:-analyze}
COUNT=$3

if [ -z "$BASE_URL" ]; then
  echo "❌ Error: Base URL is required."
  echo "Usage: $0 <base_url> [task] [count]"
  echo ""
  echo "Examples:"
  echo "  $0 https://my-app.com analyze"
  echo "  $0 https://my-app.com overload_cpu 5"
  echo "  $0 https://my-app.com overload_memory 3 (To force OOM)"
  exit 1
fi

send_request() {
  local endpoint=$1
  local payload=$2
  local id=$3
  
  if [ -z "$payload" ]; then
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}${endpoint}" -H 'Content-Type: application/json')
  else
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}${endpoint}" -H 'Content-Type: application/json' --data-raw "$payload")
  fi
  
  if [ -n "$id" ]; then
      echo "[$(date +%H:%M:%S)] [Req $id] Sent to ${endpoint} | Response: ${response}"
  else
      echo "[$(date +%H:%M:%S)] Sent to ${endpoint} | Response: ${response}"
  fi
}

echo "🚀 Starting Load Generator..."
echo "📍 Target: $BASE_URL"
echo "⚡ Task:   $TASK"
echo "---------------------------------------------------"

case "$TASK" in
  "analyze")
    echo "🔄 Generating continuous traffic... (Press CTRL+C to stop)"
    while true; do
      send_request "/analyze" '{"data":"Load Test Payload"}'
      sleep 0.5
    done
    ;;
    
  "overload_cpu")
    REQ_COUNT=${COUNT:-3}
    echo "🔥 Triggering CPU Overload (${REQ_COUNT}x requests in parallel)..."
    
    for i in $(seq 1 $REQ_COUNT); do
        send_request "/stress/cpu" "" "$i" &
    done
    
    wait
    echo "✅ CPU overload requests completed."
    ;;
    
  "overload_memory")
    REQ_COUNT=${COUNT:-2}
    echo "💧 Triggering Memory Leak (${REQ_COUNT}x requests)..."
    echo "   (Each request allocates ~200MB. Use count >= 3 to likely force OOM)"
    
    for i in $(seq 1 $REQ_COUNT); do
        send_request "/stress/memory" "" "$i"
        sleep 1
    done
    echo "✅ Allocated ~$(($REQ_COUNT * 200))MB. Check for alerts/restarts."
    ;;

  "reset")
    echo "🧹 Resetting Backend State..."
    send_request "/reset"
    echo "✅ Memory cleared and GC triggered."
    ;;
    
  *)
    echo "❌ Unknown task: $TASK"
    echo "Available tasks: analyze, overload_cpu, overload_memory, reset"
    exit 1
    ;;
esac