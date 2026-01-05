# Integration Tests

## System status contract

`SystemStatusIntegrationTest` verifies two things:
- The gateway itself is healthy via `GET /actuator/health` (expects `status: UP`).
- `GET /api/gateway/system/status` lists only downstream services (catalog, orders, billing, notification, analytics), each `status: UP`.

The gateway is not expected to appear in the downstream service list.
