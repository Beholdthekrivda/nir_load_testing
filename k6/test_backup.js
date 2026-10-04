import { sleep } from 'k6';
import { Writer } from 'k6/x/kafka';

const writer = new Writer({
    brokers: ['kafka:9092'],
    topic: 'internet_store',
    autoCreateTopic: true,
});

export const options = {
    scenarios: {
        stress_test: {
            executor: 'constant-arrival-rate',
            rate: 25,
      	    timeUnit: '1s',
	    duration: '3m',
            preAllocatedVUs: 10,
            maxVUs: 50,       
	},
    },
};

const users = Array.from({ length: 100 }, (_, i) => `user_${i + 1}`);
const products = Array.from({ length: 100 }, (_, i) => `product_${i + 101}`);

const actions = [
    { name: 'login', weight: 0.1 },
    { name: 'logout', weight: 0.1 },
    { name: 'add_to_cart', weight: 0.3 },
    { name: 'remove_from_cart', weight: 0.2 },
    { name: 'place_order', weight: 0.3 },
];

function getAction() {
    let r = Math.random();
    for (const a of actions) {
        r -= a.weight;
        if (r <= 0) return a.name;
    }
    return actions[0].name;
}

export default function () {
    const userId = users[Math.floor(Math.random() * users.length)];
    const action = getAction();
    const timestamp = Date.now() / 1000;

    let key = '';
    let payload = {};

    if (action === 'login' || action === 'logout') {
        key = `ACCOUNT::${userId}`;
        payload = { type: 'account', action: action, user_id: userId, timestamp: timestamp };
    }
    else if (action === 'add_to_cart' || action === 'remove_from_cart') {
        key = `CART::${userId}`;
        payload = {
            type: 'cart',
            action: action,
            user_id: userId,
            product_id: products[Math.floor(Math.random() * products.length)],
            quantity: Math.floor(Math.random() * 5) + 1,
            timestamp: timestamp,
        };
    }
    else {
        const orderId = `order_${Math.random().toString(16).slice(2, 10)}`;
        key = `ORDER::${orderId}`;

        const items = [];
        const itemsCount = Math.floor(Math.random() * 10) + 1;
        for (let i = 0; i < itemsCount; i++) {
            items.push({
                product_id: products[Math.floor(Math.random() * products.length)],
                quantity: Math.floor(Math.random() * 3) + 1,
            });
        }

        payload = {
            type: 'order',
            action: action,
            user_id: userId,
            order_id: orderId,
            items: items,
            timestamp: timestamp,
            priority: ['low', 'medium', 'high'][Math.floor(Math.random() * 3)],
        };
    }

    writer.produce({
        messages: [
            { key: key, value: JSON.stringify(payload) },
        ],
    });
}

export function teardown() {
    writer.close();
}
