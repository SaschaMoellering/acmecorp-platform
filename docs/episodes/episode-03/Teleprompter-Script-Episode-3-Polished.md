# Episode 3 — API Boundaries, Gateway & Error Containment

## Opening – Where systems really fail

In Episode 2, we got the AcmeCorp Platform running locally using Docker Compose. We also established a non-negotiable rule: all interaction goes through the Gateway. That rule isn't about convenience—it's about survival.

Distributed systems almost never fail because of a single bug. They fail when boundaries are unclear: when internal APIs leak, when errors propagate uncontrolled, when clients start depending on implementation details that were never meant to be public.

In this episode, we're going to sharpen the most important boundary in the system: the API boundary. We'll look at how the Gateway enforces this boundary, how it translates errors, and why this matters for everything that comes after.

---

## External vs internal APIs – The contract vs implementation split
**[DIAGRAM: E03-D01-gateway-external-vs-internal]**

Let me show you something in the docker-compose file. We have six services running: Orders, Billing, Notification, Analytics, Catalog, and the Gateway. Each of these services exposes ports—8081, 8082, 8083, 8084, 8085—but here's the thing: those ports are only exposed for debugging and local development. In production, they wouldn't be accessible at all.

The Gateway is the only service that exposes a public API. Everything else is internal. This distinction is critical because external APIs are contracts—they're promises to clients that we can't break without coordination. Internal APIs are implementation details—they're free to evolve, refactor, and change as the system grows.

If we exposed the Orders Service API directly to clients, three things would happen. First, clients would couple to internal URLs and endpoints. Second, they'd start relying on internal data structures. Third, any refactoring we do inside the Orders Service would become a breaking change for every client. That's architectural debt we don't want.

In AcmeCorp, the Gateway exposes the only public API. Every other service API is internal and free to evolve. This is the foundation of everything else we're going to talk about.

---

## Why the Gateway is not just routing
**[DIAGRAM: E03-D02-gateway-request-flow]**

A Gateway that only routes traffic is architectural debt. If all it does is forward requests from `/api/gateway/orders` to `http://orders-service:8080/api/orders`, then it's just adding latency without adding value.

The Gateway earns its place by centralizing cross-cutting concerns. Let me open the GatewayService class and show you what I mean. This is where all the real work happens.

First, look at how it's constructed. It takes five base URLs—one for each backend service—and builds a WebClient. This WebClient is Spring's reactive HTTP client, and it's what we use to make non-blocking calls to the backend services.

Now look at the `orderDetails` method. This is a read path that aggregates data from multiple services. It fetches the order from the Orders Service, then fetches invoices for that order from the Billing Service, and optionally fetches the order history. All of this happens in parallel using `Mono.zip`, and the Gateway assembles the final response.

This is aggregation. The client makes one request to the Gateway, and the Gateway coordinates multiple backend calls. The client doesn't need to know that orders and invoices live in different services—that's an internal implementation detail.

Now look at the `createOrder` method. This is a write path. It accepts an `OrderRequest` and an optional `Idempotency-Key` header. If the idempotency key is provided, it forwards it to the Orders Service, which uses it to prevent duplicate order creation if the client retries the request.

This is where the Gateway enforces rules. It validates the request, normalizes headers, and ensures that the backend services receive well-formed input. If the Orders Service changes its internal API, we update the Gateway, and the external API stays stable.

This is why Episode 2 insisted on Gateway-based local verification. If the Gateway is the boundary, it must behave the same locally, in CI, and in production. Otherwise, we're testing something that doesn't match reality.

---

## Service boundaries vs API boundaries
**[DIAGRAM: E03-D01-gateway-external-vs-internal – boundary emphasis]**

Let me clarify something that trips people up: a microservice boundary is not the same thing as an API boundary.

A microservice boundary defines ownership. Orders, Catalog, Billing, Notifications, and Analytics are service boundaries. Each one owns its own database, its own domain logic, and its own deployment lifecycle.

An API boundary defines responsibility. The Gateway is the API boundary. It's responsible for exposing a stable, versioned, well-documented API to clients. It's responsible for translating internal service responses into external API responses. It's responsible for ensuring that internal changes don't break external clients.

These are not the same thing. You can have five microservices and one API boundary. You can refactor the internal services, split them, merge them, change their data models—and as long as the Gateway translates correctly, the external API stays stable.

This is what allows services to evolve independently without exposing instability to clients.

---

## Read paths vs write paths – Different rules for different operations
**[DIAGRAM: E03-D02-gateway-request-flow – read vs write emphasis]**

Not all requests are equal. The Gateway treats read paths and write paths differently because they have different requirements.

Read paths—like `listOrders`, `catalog`, `orderDetails`—often aggregate data from multiple services. They may tolerate partial degradation. If the Billing Service is down and we can't fetch invoices, we might still return the order data with a note that invoices are unavailable. Read paths prioritize latency and consistency.

Write paths—like `createOrder`, `confirmOrder`, `cancelOrder`—change system state. They must enforce rules strictly. If the Orders Service is down, we can't create an order. If the Billing Service is down, we can't confirm an order because we can't generate an invoice. Write paths trigger downstream side effects, so they have to be reliable.

Look at the `createOrder` method again. It forwards the request to the Orders Service and waits for a response. If the Orders Service returns an error, the Gateway propagates that error to the client. There's no fallback here because creating an order is a state change—we can't fake it.

Now look at the `systemStatus` method. This is a read path that checks the health of all backend services. It uses `Flux.fromIterable` to fan out requests to all services in parallel, then collects the results. If one service is down, it marks that service as DOWN but still returns the status of the other services. This is partial degradation—we return what we can.

The Gateway allows us to treat these paths differently without leaking complexity to the client. The client just makes a request to `/api/gateway/orders` or `/api/gateway/system/status`, and the Gateway decides how to handle it.

---

## Error propagation and containment – The boundary that matters
**[DIAGRAM: E03-D03-error-propagation-paths]**

Failure is inevitable. What matters is where it's contained.

Without a Gateway boundary, downstream timeouts reach the client directly. Internal error messages leak. Clients start implementing service-specific workarounds. You end up with clients that know too much about your internal architecture, and that makes refactoring impossible.

With a Gateway boundary, errors are translated into stable external responses. Retry and fallback behavior is centralized. Clients see consistent semantics.

Let me show you the error handling code. Open `GatewayApiExceptionHandler`. This is a Spring `@RestControllerAdvice` that catches exceptions thrown by the Gateway and translates them into standardized error responses.

Look at the `handleWebClientResponseException` method. This catches errors from backend services. When the Orders Service returns a 404 or a 400 or a 500, the Gateway catches it here. It parses the response body to see if the backend service returned a structured error. If it did, the Gateway forwards that error to the client. If it didn't, the Gateway wraps it in a generic `UPSTREAM_ERROR` response.

Now look at the `handleValidation` method. This catches validation errors—like when a client sends a request with missing required fields. The Gateway collects all the validation errors, formats them into a structured response, and returns a 400 with a clear message.

Now look at the `handle` method at the bottom. This is the catch-all. If something unexpected happens—a NullPointerException, a database timeout, anything—the Gateway catches it here and returns a generic 500 error. The client never sees the internal stack trace. They just see "Internal server error" and a trace ID they can use to look up the details in the logs.

This is error containment. The Gateway is the boundary where internal failures are translated into external responses. The client sees a stable error surface, and we can change the internal implementation without breaking clients.

---

## Error taxonomy and mapping – A small, stable error surface
**[DIAGRAM: E03-D04-error-taxonomy]**

Not all errors are equal. The Gateway enforces a clear taxonomy.

4xx errors are client errors. The client sent a bad request, or they're not authorized, or the resource doesn't exist. These are errors the client can fix by changing their request.

5xx errors are server-side failures. Something went wrong on our side—a service is down, a database is unreachable, a timeout occurred. These are errors the client can't fix. They can retry, but they can't change their request to make it work.

Look at the `mapStatusToError` method in the exception handler. This maps HTTP status codes to error codes. If the backend service returns a 502, 503, or 504, the Gateway maps it to `UPSTREAM_ERROR`. If it returns a 404, the Gateway maps it to `NOT_FOUND`. If it returns a 409, the Gateway maps it to `CONFLICT`.

Internal services may fail in many ways. They might return a 500 with a stack trace. They might return a 503 with a circuit breaker message. They might time out and return nothing. Externally, we expose a small, stable error surface: `BAD_REQUEST`, `NOT_FOUND`, `CONFLICT`, `UPSTREAM_ERROR`, `INTERNAL_ERROR`. That's it.

This is what allows us to change the internal error handling without breaking clients. As long as we map internal errors to the same external error codes, the client doesn't need to change.

---

## Retries, timeouts, and circuit breakers – Resilience at the boundary
**[DIAGRAM: E03-D05-retry-circuit-breaker]**

Resilience belongs at the boundary. Retries inside services amplify load. If the Orders Service retries a call to the Billing Service, and the Gateway retries the call to the Orders Service, you get exponential retry storms. That's how you turn a small outage into a cascading failure.

Retries at the Gateway are controlled. The Gateway decides whether a request is safe to retry. If it's a GET request, it's idempotent—we can retry it. If it's a POST request without an idempotency key, it's not safe to retry because we might create duplicate orders.

Circuit breakers prevent cascading failures. If the Billing Service is down, the Gateway can open a circuit breaker and stop sending requests to it. Instead of waiting for timeouts on every request, the Gateway fails fast and returns an error immediately. This protects the Billing Service from being overwhelmed when it comes back online.

Right now, the AcmeCorp Gateway doesn't have explicit circuit breakers implemented—that's something we'd add using a library like Resilience4j. But the architecture is designed for it. The Gateway is the place where we'd add circuit breakers, because it's the boundary where we can make decisions about retries, timeouts, and fallbacks without affecting the internal services.

This is where we decide whether a failure is contained or amplified.

---

## Concrete example – Following a request through the boundary

Let me walk through a concrete example. A client wants to create an order. They send a POST request to `/api/gateway/orders` with a JSON body containing the customer email and a list of items.

The request hits the Gateway. The `GatewayController` receives it and calls `gatewayService.createOrder`. The Gateway validates the request—it checks that the customer email is present, that the items list is not empty, that the product IDs are valid UUIDs. If validation fails, the Gateway returns a 400 error with a structured response listing the validation errors.

If validation passes, the Gateway forwards the request to the Orders Service at `http://orders-service:8080/api/orders`. It includes the `Idempotency-Key` header if the client provided one. The Orders Service processes the request, creates the order in the database, publishes an event to RabbitMQ, and returns the order response.

The Gateway receives the response from the Orders Service. It wraps it in a `Mono<OrderSummary>` and returns it to the client. The client sees a 200 response with the order details.

Now let's say the Orders Service is down. The Gateway tries to connect to `http://orders-service:8080/api/orders`, but the connection times out. The Gateway catches the `WebClientResponseException`, wraps it in an `UPSTREAM_ERROR` response, and returns a 502 to the client. The client sees a clear error message: "Upstream error: orders-service unavailable."

The client never sees the internal timeout. They never see the connection refused error. They just see a structured error response with a trace ID they can use to report the issue.

This is the boundary in action. The Gateway is where internal failures are translated into external responses.

---

## Why this matters for the next episode

Strong API boundaries are a prerequisite for observability. Metrics, logs, and traces only make sense when boundaries are clear.

If clients are calling internal services directly, you can't measure the external API latency. You can't track the error rate of the public API. You can't trace a request from the client through the Gateway to the backend services and back.

In Episode 4, we're going to add observability to the platform. We're going to deploy Prometheus, Grafana, and Alertmanager. We're going to look at metrics, dashboards, and alerts. And all of that is only possible because we have a clear API boundary at the Gateway.

The Gateway is where we measure external API latency. The Gateway is where we track error rates. The Gateway is where we start distributed traces. Without the Gateway, observability is just a collection of disconnected metrics from individual services.

---

## Closing – Containment over elegance

Good API design is not about elegance. It's about containment.

Boundaries are what allow systems to evolve without breaking. The Gateway is the boundary that protects clients from internal changes. It's the boundary that translates errors. It's the boundary that enforces rules. It's the boundary that makes observability possible.

In the next episode, we'll make these boundaries observable.
