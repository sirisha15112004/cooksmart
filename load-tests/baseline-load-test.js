import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '10s', target: 50 },  // Ramp-up to 50 users
        { duration: '40s', target: 100 }, // Sustain 100 Virtual Users
        { duration: '10s', target: 0 },   // Ramp-down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
        http_req_failed: ['rate<0.01'],   // Error rate below 1%
    },
};

const BASE_URL = __ENV.API_URL || 'http://127.0.0.1:5000';

export default function () {
    // 1. Health check
    const healthRes = http.get(`${BASE_URL}/health`);
    check(healthRes, { 'Health status 200': (r) => r.status === 200 });

    // 2. Fetch recipes
    const recipesRes = http.get(`${BASE_URL}/recipes/1?favorite=true`);
    check(recipesRes, { 'Recipes status 200': (r) => r.status === 200 });

    // 3. Fetch meal plan
    const planRes = http.get(`${BASE_URL}/meal_plan/1?date=2026-08-26`);
    check(planRes, { 'Meal plan status 200': (r) => r.status === 200 });

    // 4. Fetch dashboard
    const dashRes = http.get(`${BASE_URL}/dashboard/1`);
    check(dashRes, { 'Dashboard status 200': (r) => r.status === 200 });

    sleep(1);
}
