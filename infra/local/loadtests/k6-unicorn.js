import http from "k6/http";
import { check, sleep } from "k6";

const rawBaseUrl = __ENV.BASE_URL || "http://gateway-service:8080";
const BASE_URL = rawBaseUrl.replace(/\/+$/, "");
const RATE = Number.parseInt(__ENV.RATE || "2", 10);
const DURATION = __ENV.DURATION || "30m";
const WRITE_RATE = Number.parseFloat(__ENV.WRITE_RATE || "0.2");

const ORDER_LIST_SIZE = 20;
const ID_POOL_SIZE = 50;
const CATALOG_FALLBACK_IDS = [
  "11111111-1111-1111-1111-111111111111",
  "22222222-2222-2222-2222-222222222222",
  "33333333-3333-3333-3333-333333333333",
  "44444444-4444-4444-4444-444444444444",
];

export const options = {
  scenarios: {
    steady: {
      executor: "constant-arrival-rate",
      rate: RATE,
      timeUnit: "1s",
      duration: DURATION,
      preAllocatedVUs: Math.max(4, RATE),
      maxVUs: Math.max(12, RATE * 2),
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<2000"],
  },
};

const flows = [
  { name: "browse", weight: 60 },
  { name: "order", weight: 25 },
  { name: "misc", weight: 15 },
];
const totalFlowWeight = flows.reduce((sum, flow) => sum + flow.weight, 0);

function pickFlow() {
  const roll = Math.random() * totalFlowWeight;
  let cursor = 0;
  for (const flow of flows) {
    cursor += flow.weight;
    if (roll <= cursor) {
      return flow.name;
    }
  }
  return "browse";
}

function okRead(res) {
  return res.status >= 200 && res.status < 400;
}

function okWrite(res) {
  return res.status >= 200 && res.status < 300;
}

function sleepJitter() {
  sleep(0.2 + Math.random() * 1.3);
}

function safeJson(res) {
  try {
    return res.json();
  } catch (_) {
    return null;
  }
}

function pickRandom(list) {
  if (!list || list.length === 0) {
    return null;
  }
  return list[Math.floor(Math.random() * list.length)];
}

function orderPayload() {
  return {
    customerEmail: `loadtest+${__VU}-${__ITER}@example.com`,
    items: [
      {
        productId: "11111111-1111-1111-1111-111111111111",
        quantity: 1,
      },
    ],
  };
}

function browseFlow() {
  const catalogRes = http.get(`${BASE_URL}/api/gateway/catalog`, {
    tags: { route: "GET /api/gateway/catalog", flow: "browse" },
  });
  check(catalogRes, { "catalog list ok": okRead });

  let productId = pickRandom(CATALOG_FALLBACK_IDS);
  const catalogJson = safeJson(catalogRes);
  if (Array.isArray(catalogJson) && catalogJson.length > 0) {
    const candidate = pickRandom(catalogJson);
    if (candidate && candidate.id) {
      productId = candidate.id;
    }
  }

  const batchRes = http.batch([
    [
      "GET",
      `${BASE_URL}/api/gateway/catalog/${productId}`,
      null,
      { tags: { route: "GET /api/gateway/catalog/:id", flow: "browse" } },
    ],
    [
      "GET",
      `${BASE_URL}/api/gateway/orders?size=${ORDER_LIST_SIZE}`,
      null,
      { tags: { route: "GET /api/gateway/orders", flow: "browse" } },
    ],
  ]);

  check(batchRes[0], { "catalog detail ok": okRead });
  check(batchRes[1], { "orders list ok": okRead });
}

function writeFlow(orderId) {
  const action = Math.random() < 0.7 ? "confirm" : "cancel";
  const writeRes = http.post(
    `${BASE_URL}/api/gateway/orders/${orderId}/${action}`,
    null,
    { tags: { route: `POST /api/gateway/orders/:id/${action}`, flow: "order" } }
  );

  check(writeRes, { "order write ok": okWrite });
  if (!okWrite(writeRes) && Math.random() < 0.05) {
    console.error(`order ${action} failed: ${writeRes.status}`);
  }

  const readRes = http.get(`${BASE_URL}/api/gateway/orders/${orderId}`, {
    tags: { route: "GET /api/gateway/orders/:id", flow: "order" },
  });
  check(readRes, { "order detail ok": okRead });
}

function createOrderFallback() {
  const idempotencyKey = `k6-${Math.floor(Math.random() * ID_POOL_SIZE)}`;
  const payload = JSON.stringify(orderPayload());
  const createRes = http.post(`${BASE_URL}/api/gateway/orders`, payload, {
    tags: { route: "POST /api/gateway/orders", flow: "order" },
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": idempotencyKey,
    },
  });

  check(createRes, { "order create ok": okWrite });
  if (!okWrite(createRes) && Math.random() < 0.05) {
    console.error(`order create failed: ${createRes.status}`);
    return;
  }

  const created = safeJson(createRes);
  if (created && created.id) {
    const readRes = http.get(`${BASE_URL}/api/gateway/orders/${created.id}`, {
      tags: { route: "GET /api/gateway/orders/:id", flow: "order" },
    });
    check(readRes, { "order detail ok": okRead });
  }
}

function orderFlow() {
  const listRes = http.get(`${BASE_URL}/api/gateway/orders?size=${ORDER_LIST_SIZE}`, {
    tags: { route: "GET /api/gateway/orders", flow: "order" },
  });
  check(listRes, { "orders list ok": okRead });
  const payload = safeJson(listRes);
  const hasOrders = payload && Array.isArray(payload.content) && payload.content.length > 0;
  const candidate = hasOrders ? pickRandom(payload.content) : null;
  const orderId = candidate && candidate.id ? candidate.id : null;

  if (Math.random() > WRITE_RATE) {
    const readUrl = orderId
      ? `${BASE_URL}/api/gateway/orders/${orderId}`
      : `${BASE_URL}/api/gateway/orders/latest`;
    const readRoute = orderId ? "GET /api/gateway/orders/:id" : "GET /api/gateway/orders/latest";
    const readRes = http.get(readUrl, {
      tags: { route: readRoute, flow: "order" },
    });
    check(readRes, { "order read ok": okRead });
    return;
  }

  if (orderId) {
    writeFlow(orderId);
    return;
  }

  if (hasOrders) {
    const fallbackId = Math.floor(Math.random() * ID_POOL_SIZE) + 1;
    writeFlow(fallbackId);
  } else {
    createOrderFallback();
  }
}

function miscFlow() {
  const pick = Math.random() < 0.5 ? "analytics" : "system";
  if (pick === "analytics") {
    const res = http.get(`${BASE_URL}/api/gateway/analytics/counters`, {
      tags: { route: "GET /api/gateway/analytics/counters", flow: "misc" },
    });
    check(res, { "analytics counters ok": okRead });
  } else {
    const res = http.get(`${BASE_URL}/api/gateway/system/status`, {
      tags: { route: "GET /api/gateway/system/status", flow: "misc" },
    });
    check(res, { "system status ok": okRead });
  }
}

export default function () {
  const flow = pickFlow();
  if (flow === "browse") {
    browseFlow();
  } else if (flow === "order") {
    orderFlow();
  } else {
    miscFlow();
  }
  sleepJitter();
}
