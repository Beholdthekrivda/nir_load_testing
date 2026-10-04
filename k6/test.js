import { Writer } from 'k6/x/kafka';
import { SharedArray } from 'k6/data';

const writer = new Writer({
    brokers: ['kafka:9092'],
    topic: 'internet_store',
    autoCreateTopic: true,
});

export const options = {
    scenarios: {
        stress_test: {
            executor: 'constant-arrival-rate',
            rate: 20,
            timeUnit: '1s',
            duration: '3m',
            preAllocatedVUs: 10,
            maxVUs: 50,       
        },
    },
};

function getRandomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

const CPU_N = 30;

const payloads = new SharedArray('payloads', function () {
    return JSON.parse(open('./payloads.json'));
});

export default function () {
    const item = payloads[Math.floor(Math.random() * payloads.length)]
	
    const payload = {
	type: item.type,
	cpu_n: item.cpu_n,
	label: item.label,
	timestamp: Date.now() / 1000,
    };

    const key = 'CPU::' + getRandomInt(1, 100);

    writer.produce({
        messages: [
	    { key: key, value: JSON.stringify(payload) }
	], 
    });
}

export function teardown() {
    writer.close();
}
