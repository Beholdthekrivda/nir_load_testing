from confluent_kafka import Consumer, KafkaException, KafkaError
import json
import time
import os
import random

conf = {
    'bootstrap.servers': os.environ['KAFKA_BROKER'],
    'group.id': 'shop-workers',
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False,
    'session.timeout.ms': 45000,
    'max.poll.interval.ms': 300000
}

consumer = Consumer(conf)
consumer.subscribe(['internet_store'])

worker_id = os.getenv('HOSTNAME', 'worker-unknown')

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

def process_fib(message):
    n = min(int(message.get('cpu_n', 30)), 35)
    fib(n)
    return True

def process_message(message):
    msg_type = message.get('type', 'unknown')
    
    handlers = {
        'cpu': process_fib
    }
    
    handler = handlers.get(msg_type)
    if not handler:
        print(f"[{worker_id}] Unknown message type: {msg_type}")
        return False
    
    try:
        return handler(message)
    except Exception as e:
        print(f"[{worker_id}] Processing error for {msg_type}: {str(e)}")
        return False

print(f"Worker {worker_id} started. Waiting for messages...")
try:
    while True:
        msg = consumer.poll(timeout=1.0)
        if msg is None:
            continue
            
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                continue
            raise KafkaException(msg.error())
        
        message = json.loads(msg.value().decode('utf-8'))   
        
        if process_message(message):
            consumer.commit(msg)
            
except KeyboardInterrupt:
    print(f"[{worker_id}] Shutting down gracefully")
finally:
    consumer.close()
