#!/bin/bash

# Startup Benchmarking Script for AcmeCorp Platform
# Usage: ./scripts/bench/startup.sh [service-name] [iterations]

set -euo pipefail

SERVICE_NAME=${1:-"orders-service"}
ITERATIONS=${2:-3}
TIMEOUT=${3:-60}

echo "=== AcmeCorp Platform Startup Benchmark ==="
echo "Service: $SERVICE_NAME"
echo "Iterations: $ITERATIONS"
echo "Timeout: ${TIMEOUT}s"
echo "Branch: $(git branch --show-current)"
echo "Date: $(date)"
echo

# Detect service type and port
case "$SERVICE_NAME" in
    "gateway-service") PORT=8080 ;;
    "orders-service") PORT=8081 ;;
    "billing-service") PORT=8082 ;;
    "notification-service") PORT=8083 ;;
    "analytics-service") PORT=8084 ;;
    "catalog-service") PORT=8085 ;;
    *) echo "Unknown service: $SERVICE_NAME"; exit 1 ;;
esac

# Health endpoint based on service type
if [[ "$SERVICE_NAME" == "catalog-service" ]]; then
    HEALTH_ENDPOINT="http://localhost:$PORT/q/health"
else
    HEALTH_ENDPOINT="http://localhost:$PORT/actuator/health"
fi

echo "Health endpoint: $HEALTH_ENDPOINT"
echo

# Function to measure startup time
measure_startup() {
    local iteration=$1
    echo "--- Iteration $iteration ---"
    
    # Stop any existing container
    docker stop "$SERVICE_NAME" 2>/dev/null || true
    docker rm "$SERVICE_NAME" 2>/dev/null || true
    
    # Start timing
    local start_time=$(date +%s.%N)
    
    # Start container
    echo "Starting container..."
    docker run -d --name "$SERVICE_NAME" \
        -p "$PORT:8080" \
        --network acmecorp-local_default \
        -e SPRING_DATASOURCE_URL="jdbc:postgresql://acmecorp-postgres:5432/acmecorp" \
        -e SPRING_DATASOURCE_USERNAME="acmecorp" \
        -e SPRING_DATASOURCE_PASSWORD="acmecorp123" \
        -e SPRING_RABBITMQ_HOST="acmecorp-rabbitmq" \
        -e SPRING_REDIS_HOST="acmecorp-redis" \
        "local-$SERVICE_NAME:latest" > /dev/null
    
    # Wait for health endpoint
    echo "Waiting for health endpoint..."
    local ready=false
    local elapsed=0
    
    while [[ $elapsed -lt $TIMEOUT ]]; do
        if curl -sf "$HEALTH_ENDPOINT" > /dev/null 2>&1; then
            ready=true
            break
        fi
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    
    local end_time=$(date +%s.%N)
    local startup_time=$(echo "$end_time - $start_time" | bc -l)
    
    if [[ "$ready" == "true" ]]; then
        printf "Startup time: %.3f seconds\n" "$startup_time"
        
        # Get memory usage
        local memory_mb=$(docker stats --no-stream --format "{{.MemUsage}}" "$SERVICE_NAME" | cut -d'/' -f1 | sed 's/MiB//' | sed 's/MB//' | tr -d ' ')
        echo "Memory usage: ${memory_mb}MB"
        
        # Get image size
        local image_size=$(docker images "local-$SERVICE_NAME:latest" --format "{{.Size}}")
        echo "Image size: $image_size"
        
        echo "$startup_time" >> "/tmp/${SERVICE_NAME}_startup_times.txt"
    else
        echo "TIMEOUT: Service did not become ready within ${TIMEOUT}s"
        startup_time="TIMEOUT"
    fi
    
    # Cleanup
    docker stop "$SERVICE_NAME" > /dev/null 2>&1 || true
    docker rm "$SERVICE_NAME" > /dev/null 2>&1 || true
    
    echo
    return 0
}

# Check if Docker image exists
if ! docker images "local-$SERVICE_NAME:latest" --format "{{.Repository}}" | grep -q "local-$SERVICE_NAME"; then
    echo "Error: Docker image 'local-$SERVICE_NAME:latest' not found"
    echo "Please build the image first:"
    echo "  cd services/spring-boot/$SERVICE_NAME (or services/quarkus/$SERVICE_NAME)"
    echo "  docker build -t local-$SERVICE_NAME:latest ."
    exit 1
fi

# Check dependencies
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' command not found. Please install bc for calculations."
    exit 1
fi

# Clear previous results
rm -f "/tmp/${SERVICE_NAME}_startup_times.txt"

# Run benchmark iterations
for i in $(seq 1 $ITERATIONS); do
    measure_startup $i
    if [[ $i -lt $ITERATIONS ]]; then
        echo "Waiting 5 seconds before next iteration..."
        sleep 5
    fi
done

# Calculate statistics
if [[ -f "/tmp/${SERVICE_NAME}_startup_times.txt" ]]; then
    echo "=== RESULTS SUMMARY ==="
    
    local times=($(cat "/tmp/${SERVICE_NAME}_startup_times.txt" | grep -v TIMEOUT))
    local count=${#times[@]}
    
    if [[ $count -gt 0 ]]; then
        # Calculate average
        local sum=0
        for time in "${times[@]}"; do
            sum=$(echo "$sum + $time" | bc -l)
        done
        local avg=$(echo "scale=3; $sum / $count" | bc -l)
        
        # Find min and max
        local min=${times[0]}
        local max=${times[0]}
        for time in "${times[@]}"; do
            if (( $(echo "$time < $min" | bc -l) )); then
                min=$time
            fi
            if (( $(echo "$time > $max" | bc -l) )); then
                max=$time
            fi
        done
        
        printf "Successful iterations: %d/%d\n" "$count" "$ITERATIONS"
        printf "Average startup time: %.3f seconds\n" "$avg"
        printf "Min startup time: %.3f seconds\n" "$min"
        printf "Max startup time: %.3f seconds\n" "$max"
        
        # Save results with branch info
        local branch=$(git branch --show-current)
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local results_file="bench_results_${SERVICE_NAME}_${branch}_${timestamp}.txt"
        
        {
            echo "Service: $SERVICE_NAME"
            echo "Branch: $branch"
            echo "Date: $(date)"
            echo "Iterations: $ITERATIONS"
            echo "Average: ${avg}s"
            echo "Min: ${min}s"
            echo "Max: ${max}s"
            echo "Raw times: ${times[*]}"
        } > "$results_file"
        
        echo "Results saved to: $results_file"
    else
        echo "No successful startups recorded"
    fi
    
    # Cleanup
    rm -f "/tmp/${SERVICE_NAME}_startup_times.txt"
fi

echo
echo "Benchmark complete!"