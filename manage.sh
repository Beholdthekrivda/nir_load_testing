#!/bin/bash
set -e

cleanup() {
    set +e
	
    # if [ docker stop manual_worker ]; then
    #   docker rm $(docker ps -a | grep manual_worker | awk '{print $1}')	
    # fi

    docker-compose down

    exit 1
}

trap cleanup INT TSTP TERM

wait_for_kafka() {
    echo "Waiting for Kafka readiness (max 3 minutes)..."
    MAX_ATTEMPTS=18
    ATTEMPT=0
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if docker-compose exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 >/dev/null 2>&1; then
            echo "Kafka is ready!"
            return 0
        fi
        ATTEMPT=$((ATTEMPT+1))
        echo "Kafka not ready yet... Attempt $ATTEMPT/$MAX_ATTEMPTS"
       	sleep 1
    done
    
    echo "Kafka failed to start within timeout"
    exit 1
}

manage_topic() {
    local partitions=$1
    
    if docker-compose exec kafka bash -c "kafka-topics \
	--bootstrap-server localhost:9092 \
	--list | grep -q 'internet_store'"; then
        
        echo "Increasing partitions to $partitions..."
        docker-compose exec kafka kafka-topics \
          --bootstrap-server localhost:9092 \
          --alter \
          --topic internet_store \
          --partitions $partitions
    else
        echo "Creating topic with $partitions partitions..."
        docker-compose exec kafka kafka-topics \
          --bootstrap-server localhost:9092 \
          --create \
          --topic internet_store \
          --partitions $partitions \
          --replication-factor 1
    fi
}

scale_workers() {
    local workers=$1
    echo "Scaling workers to $workers instances..."
    docker-compose up -d --build --scale worker=$workers worker
}

scale_worker_test() {
    local cpu=$1
    local ram=$2
    
    echo "Сборка свежего образа воркера..."
    docker-compose build worker
    
    echo "Запуск тестового воркера с лимитами -> CPU: $cpu, RAM: ${ram}M..."
    # Запускаем один воркер вручную через docker run в сеть проекта
    docker run -d \
      --name manual_worker \
      --network "shop_net" \
      --cpus="$cpu" \
      -m "${ram}m" \
      -e KAFKA_BROKER="kafka:9092" \
      nir_worker
}

case "$1" in
    test)
	docker-compose down -v
       
        docker-compose up -d zookeeper
        
        docker-compose up -d kafka
        wait_for_kafka
	
	manage_topic 1

	declare -a cpus
	declare -a rams
	cpus=("1" "0.5" "0.25" "0.125")
	ram="512"
	
	for cpu in "${cpus[@]}"; do
           echo "Запуск теста: cpu = $cpu, ram = ${ram}m"
	   scale_worker_test "$cpu" "$ram"
	   echo "Запуск k6"
	   docker-compose up --build --abort-on-container-exit k6

	   docker stop manual_worker
	   docker rm $(docker ps -a | grep manual_worker | awk '{print $1}')		
	done

	echo "Все тесты успешно пройдены"
	;;
    start)
	if [[ -z "$2" && -z "$3" ]]; then 
            partitions=2
            workers=2
	elif [[ -z "$2" || -z "$3" ]]; then
	    echo "Usage: $0 start <partitions> <workers>"
            exit 1
	else
	    partitions=$2
	    workers=$3
        fi

        echo "Starting system with 2 partitions and 2 workers..."
        
        docker-compose down -v
       
        docker-compose up -d zookeeper
        
        docker-compose up -d kafka
        wait_for_kafka

	# docker-compose up -d prometheus

	# docker-compose up -d cadvisor
        
        manage_topic "$partitions"
	scale_workers "$workers"

        docker-compose up -d --build k6
        
        echo "System started successfully! For monitoring:"
        echo "sudo docker compose logs -f worker"
        ;;
        
    scale)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 scale <partitions> <workers>"
            exit 1
        fi
        
        partitions=$2
        workers=$3
        
        echo "Dynamic scaling: $partitions partitions, $workers workers"
        
        if ! docker-compose ps kafka | grep -q "Up"; then
            echo "Kafka is not running. First execute: $0 start"
            exit 1
        fi
        
        wait_for_kafka
        
        manage_topic $partitions
        scale_workers $workers
        
        echo "Scaling completed!"
        echo "Current partition distribution:"
        docker-compose exec kafka kafka-consumer-groups \
          --bootstrap-server localhost:9092 \
          --group shop-workers \
       	  --describe
        ;;

    stop)
        docker-compose down -t 30
	;;

    status)
        echo "System status:"
        docker-compose ps
        echo -e "\nPartition distribution:"
        docker-compose exec kafka kafka-consumer-groups \
          --bootstrap-server localhost:9092 \
          --group shop-workers \
          --describe 2>/dev/null || echo "Consumer group not yet created"
        ;;
        
    *)
        echo "Usage:"
        echo "  $0 start <n> <m>   - Start system with n partitions and m workers"
        echo "  $0 scale <n> <m>   - Scale: n partitions, m workers"
        echo "  $0 status          - Check system status"
        exit 1
        ;;
esac
