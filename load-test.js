import http from "k6/http";
import { check, sleep } from "k6";

const rawBaseUrl = __ENV.BASE_URL || "http://orders-service:8080";
const BASE_URL = rawBaseUrl.replace(/\/+$/, "");

const ENDPOINTS = {
  latest: {
    name: "latest",
    method: "GET",
    path: "/api/orders/latest",
    weightSlotMax: 6, // 70% of 10 slots: 0-6
  },
  nplus1: {
    name: "nplus1",
    method: "GET",
    path: "/api/orders/demo/nplus1?limit=5",
    weightSlotMax: 9, // 30% of 10 slots: 7-9
  },
};

export const options = {
  stages: [
    { duration: "30s", target: 10 },
    { duration: "30s", target: 30 },
    { duration: "2m", target: 30 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1000"],
  },
};

function selectEndpoint() {
  // Deterministic 70/30 split for repeatable demo and benchmark runs.
  const slot = (__VU + __ITER) % 10;
  return slot <= ENDPOINTS.latest.weightSlotMax ? ENDPOINTS.latest : ENDPOINTS.nplus1;
}

function hasNonEmptyBody(res) {
  return typeof res.body === "string" && res.body.trim().length > 0;
}

function runRequest(endpoint) {
  const url = `${BASE_URL}${endpoint.path}`;
  const params = {
    tags: {
      service: "orders-service",
      endpoint: endpoint.name,
      route: `${endpoint.method} ${endpoint.path}`,
      test_type: "direct-orders",
    },
  };

  const res = http.get(url, params);

  check(res, {
    [`${endpoint.name} returned 200`]: (response) => response.status === 200,
    [`${endpoint.name} body is non-empty`]: hasNonEmptyBody,
  });

  return res;
}

export default function () {
  const endpoint = selectEndpoint();
  runRequest(endpoint);

  // Small pacing delay to keep the staged load readable during demos.
  sleep(0.5);
}

export function handleSummary(data) {
  const metrics = data.metrics || {};
  const durationMetric = metrics.http_req_duration || {};
  const failedMetric = metrics.http_req_failed || {};
  const requestsMetric = metrics.http_reqs || {};
  const durationValues = durationMetric.values || {};
  const failedValues = failedMetric.values || {};
  const requestValues = requestsMetric.values || {};

  const durationP95 = durationValues["p(95)"];
  const failedRate = failedValues.rate;
  const requestCount = requestValues.count;
  const safeRequestCount = requestCount === undefined || requestCount === null ? "n/a" : requestCount;
  const safeFailedRate = failedRate === undefined || failedRate === null ? "n/a" : failedRate;
  const safeDurationP95 = durationP95 === undefined || durationP95 === null ? "n/a" : durationP95;

  const lines = [
    "",
    "AcmeCorp orders-service direct load test summary",
    `BASE_URL: ${BASE_URL}`,
    `Requests: ${safeRequestCount}`,
    `http_req_failed: ${safeFailedRate}`,
    `http_req_duration p(95): ${safeDurationP95} ms`,
    "",
  ];

  return {
    stdout: `${lines.join("\n")}\n`,
  };
}
