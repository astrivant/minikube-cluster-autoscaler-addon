import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = JSON.parse(open('/demo/profile.json'));
const target = __ENV.TARGET_URL;

export function setup() {
  for (let attempt = 0; attempt < 150; attempt++) {
    if (http.get(`${target}/healthz`, { timeout: '2s' }).status === 200) {
      return;
    }
    sleep(2);
  }
  throw new Error('Receiver did not become ready');
}

export default function () {
  const response = http.get(`${target}/work`, { timeout: '10s' });
  check(response, { 'HTTP 200': (r) => r.status === 200 });
}
