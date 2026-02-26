# Episode 5 — Performance Pitfalls: Hibernate N+1 Problem

## Opening – The most dangerous bugs are invisible

In Episode 4, we built observability into the AcmeCorp platform. We can now see request rates, latency, error rates, and JVM metrics in real time. We have dashboards, alerts, and signals.

But observability only shows us that something is wrong. It doesn't tell us why. In this episode, we're going to use those signals to diagnose and fix one of the most common performance problems in production systems: the Hibernate N+1 query problem.

The most dangerous performance bugs are the ones you cannot see. ORMs like Hibernate increase productivity—they let us work with objects instead of SQL. But they also hide cost. Without deliberate measurement, teams ship performance regressions to production every day.

This episode is about making the invisible visible.

---

## What is the N+1 problem? – One query becomes many

The N+1 problem happens when you fetch a collection of entities, then access a lazy-loaded relationship on each one. Instead of fetching everything in one or two queries, the ORM executes N+1 queries: one to fetch the parent entities, then one additional query for each parent to fetch its children.

If you fetch 10 orders, and each order has items, you get 1 query for the orders plus 10 queries for the items. That's 11 queries total. If you fetch 100 orders, you get 101 queries. The problem scales linearly with the number of entities.

This is invisible in development. You test with 5 orders, and it feels fast. You deploy to production with 500 orders, and suddenly the endpoint times out.

---

## Demonstrating the problem – The broken endpoint

Before we demonstrate the N+1 problem, let me seed some test data so we have orders to work with.

```bash
curl -X POST http://localhost:8080/api/gateway/seed
```

This creates 1000 deterministic seed orders, each with 5 to 30 items.
The seed uses a fixed random seed internally, so the dataset is reproducible across runs.
The seed operation is idempotent. If I run it again, it replaces the previous demo data instead of duplicating it. Now let me show you the problem in action. I'll call the N+1 demo endpoint on the orders service.

```bash
time curl "http://localhost:8081/api/orders/demo/nplus1?limit=50"
```

This endpoint fetches 50 orders and returns them with their items. Look at the timing—around 80-90 milliseconds. Now watch what happens when we call the optimized endpoint.

```bash
time curl "http://localhost:8081/api/orders/latest"
```

This endpoint fetches 10 orders with their items using an optimized query strategy. Look at the timing—around 35-40 milliseconds. The optimized version is more than twice as fast, even though it's fetching fewer orders.

But here's the critical insight: the timing difference isn't the real problem. The real problem is the query count. The N+1 endpoint executes one query to fetch the orders, then one additional query for each order to fetch its items. With 50 orders, that's 52 queries (50 item queries + 1 for the orders + 1 pagination count). With 1000 orders, that's 1002 queries.

The optimized endpoint? It avoids the per-order fan-out. In practice you'll see either a single join fetch query, or a small “IDs” query plus a join fetch—still constant, not linear.

This is why the N+1 problem is so dangerous. It scales linearly with your data. In development with 10 test orders, it's barely noticeable. In production with 1000 orders, it becomes catastrophic. The code looks clean, but the performance degrades as your data grows.

---

## The domain model – Order and OrderItem

Let me open the Order entity in IntelliJ. This is a standard JPA entity with an `@OneToMany` relationship to OrderItem.

```java
@OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
private List<OrderItem> items = new ArrayList<>();
```

This relationship is lazy by default. When we fetch an Order, Hibernate doesn't fetch the items automatically. It only fetches them when we call `order.getItems()`.

Now let me open the OrderItem entity. This is the child entity with a `@ManyToOne` relationship back to Order.

```java
@ManyToOne(optional = false)
@JoinColumn(name = "order_id")
private Order order;
```

This is a standard bidirectional relationship. Nothing unusual here. The problem isn't in the mapping—it's in how we use it.

---

## The broken code – Triggering N+1 queries

Let me open OrderService and find the `listOrdersNPlusOneDemo` method. This is the broken endpoint.

```java
@Transactional(readOnly = true)
public List<OrderResponse> listOrdersNPlusOneDemo(int limit) {
    var pageRequest = PageRequest.of(0, Math.max(1, limit));
    return orderRepository.findAll(pageRequest)
            .getContent()
            .stream()
            .map(OrderResponse::from)
            .toList();
}
```

This looks innocent. We fetch a page of orders, map them to responses, and return the list. But look at what happens inside `OrderResponse.from`.

Let me open OrderResponse. Look at the `from` method.

```java
public static OrderResponse from(Order order) {
    return new OrderResponse(
        order.getId(),
        order.getOrderNumber(),
        order.getCustomerEmail(),
        order.getStatus(),
        order.getTotalAmount(),
        order.getCurrency(),
        order.getCreatedAt(),
        order.getUpdatedAt(),
        order.getItems().stream()  // This triggers a query for each order
            .map(OrderItemResponse::from)
            .toList()
    );
}
```

See the problem? We call `order.getItems()` inside the mapping function. This happens for every order in the list. Hibernate executes one query to fetch the orders, then one additional query for each order to fetch its items.

This is the N+1 problem. The code looks clean, but the performance is terrible.

---

## Seeing the queries – Enabling SQL logging

The timing tells us there's a problem, but to understand why, we need to see the actual SQL queries Hibernate is executing. For local Docker Compose runs, SQL logging is enabled in `application-docker.yml`:

```yaml
spring:
  jpa:
    properties:
      hibernate:
        format_sql: true

logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE
```

Let me tail the Docker logs in a separate terminal so we can watch the queries in real time.

```bash
cd infra/local
docker compose logs -f orders-service | grep -i "select"
```

With the logs streaming, let me call the N+1 endpoint with just 5 orders so we can clearly see the pattern.

```bash
curl "http://localhost:8081/api/orders/demo/nplus1?limit=5"
```

Watch the terminal with the logs. You'll see a burst of SELECT statements.

First Hibernate fetches the orders page. Because this is paginated, you'll typically see an `offset / fetch first` style query (and the bound parameters right below it):

```sql
select
    o1_0.id,
    o1_0.created_at,
    o1_0.currency,
    o1_0.customer_email,
    o1_0.order_number,
    o1_0.status,
    o1_0.total_amount,
    o1_0.updated_at
from orders o1_0
offset ? rows fetch first ? rows only
```

Then Hibernate also executes a count query for pagination:

```sql
select count(o1_0.id)
from orders o1_0
```

And then you get the classic fan‑out: one additional query per order to fetch its items:

```sql
select
    i1_0.order_id,
    i1_0.id,
    i1_0.line_total,
    i1_0.product_id,
    i1_0.product_name,
    i1_0.quantity,
    i1_0.unit_price
from order_items i1_0
where i1_0.order_id=?
```

So with `limit=5`, the pattern is:

- 1 query for the orders page
- 1 query for the count
- 5 queries for the items (one per order)

Seven queries total for five orders.

This is the N+1 problem in action: one query to fetch the parent entities, then one additional query per parent to fetch the children—plus the pagination count query on top.

Now let me call the optimized endpoint and watch the logs.

```bash
curl "http://localhost:8081/api/orders/latest"
```

Look at the difference. Instead of per‑order `where order_id=?` fan‑out, we see the items pulled in via a join fetch.

In the simplest form, it looks like a single `select distinct ... left join ...` query:

```sql
select distinct
    o1_0.id,
    o1_0.created_at,
    o1_0.currency,
    o1_0.customer_email,
    o1_0.order_number,
    o1_0.status,
    o1_0.total_amount,
    o1_0.updated_at,
    i1_0.order_id,
    i1_0.id,
    i1_0.line_total,
    i1_0.product_id,
    i1_0.product_name,
    i1_0.quantity,
    i1_0.unit_price
from orders o1_0
left join order_items i1_0 on o1_0.id=i1_0.order_id
where o1_0.id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
order by o1_0.created_at desc
```

Depending on how the endpoint is implemented, you might also see a small “IDs only” query first and then the join fetch — but the key point is: no per‑order fan‑out. The SQL logs make the problem—and the solution—completely visible.

---

## The fix – Eager fetching with join fetch

The fix is to tell Hibernate to fetch the items eagerly using a join. Let me open OrderRepository and look at the `findAllWithItemsByIds` method.

```java
@Query("""
    select distinct o
    from Order o
    left join fetch o.items
    where o.id in :ids
    order by o.createdAt desc
""")
List<Order> findAllWithItemsByIds(@Param("ids") Set<Long> ids);
```

This is a JPQL query with `left join fetch`. The `fetch` keyword tells Hibernate to eagerly load the items in the same query. Instead of N+1 queries, we get one query with a join.

Now let me look at how we use this in OrderService. Find the `listOrders` method.

```java
@Transactional(readOnly = true)
public Page<Order> listOrders(String customerEmail, OrderStatus status, int page, int size) {
    Specification<Order> spec = Specification.where(null);
    if (customerEmail != null && !customerEmail.isBlank()) {
        spec = spec.and((root, query, cb) -> cb.like(cb.lower(root.get("customerEmail")), "%" + customerEmail.toLowerCase(Locale.ROOT) + "%"));
    }
    if (status != null) {
        spec = spec.and((root, query, cb) -> cb.equal(root.get("status"), status));
    }
    Page<Order> ordersPage = orderRepository.findAll(spec, PageRequest.of(page, size));
    preloadItems(ordersPage.getContent());
    return ordersPage;
}
```

After fetching the page of orders, we call `preloadItems`. Let me find that method.

```java
private void preloadItems(List<Order> orders) {
    if (orders == null || orders.isEmpty()) {
        return;
    }
    Set<Long> ids = orders.stream()
            .map(Order::getId)
            .filter(Objects::nonNull)
            .collect(Collectors.toSet());
    if (ids.isEmpty()) {
        return;
    }
    orderRepository.findAllWithItemsByIds(ids);
}
```

This method extracts the order IDs, then calls `findAllWithItemsByIds` to eagerly fetch all the items in one query. When we later call `order.getItems()`, Hibernate returns the already-loaded items from the session cache. No additional queries.

This is the fix. Two queries instead of N+1: one to fetch the orders, one to fetch all the items.

---

## Validating the fix – Writing a test

How do we know the fix works? How do we prevent regressions? We write a test that counts queries.

Let me open OrderServiceQueryCountTest. This is a Spring Boot test that uses Hibernate statistics to count queries.

```java
@BeforeEach
void setUp() {
    var sessionFactory = emf.unwrap(SessionFactory.class);
    statistics = sessionFactory.getStatistics();
    statistics.setStatisticsEnabled(true);
    orderRepository.deleteAll();
}
```

In the setup, we enable Hibernate statistics. This lets us count how many queries Hibernate executes.

Now look at the test.

```java
@Test
void listOrdersPrefetchesItemsToAvoidNPlusOne() {
    seedOrders(10, 5);
    statistics.clear();

    orderService.listOrders(null, null, 0, 20);

    long queryCount = statistics.getPrepareStatementCount();
    assertThat(queryCount)
            .withFailMessage("Expected <=3 queries but statistics reported %d, indicates N+1", queryCount)
            .isLessThanOrEqualTo(3);
}
```

We seed 10 orders with 5 items each. We clear the statistics. We call `listOrders`. Then we assert that the query count is 3 or less.

Why 3? One query to fetch the orders. One query to fetch the items. One query for the count (pagination). If we see more than 3 queries, we have an N+1 problem.

Let me run the test.

```bash
cd services/spring-boot/orders-service
mvn -ntp test -Dtest=OrderServiceQueryCountTest
```

The test passes. Query count is 3. The fix works.

Now let me break the fix. I'll comment out the `preloadItems` call in `listOrders` and run the test again.

```bash
cd services/spring-boot/orders-service
mvn -ntp test -Dtest=OrderServiceQueryCountTest
```

The test fails. Query count is 13. One query for the orders, one for the count, and 10 queries for the items—one per order. The N+1 problem is back.

This test is our safety net. If someone refactors the code and removes the eager fetching, the test fails immediately. We catch the regression before it reaches production.

---

## Why this matters – Performance as a requirement

Performance is not an optimization. It's a requirement. If an endpoint times out under load, it doesn't matter how clean the code is. The system is broken.

The N+1 problem is invisible in development because we test with small datasets. It only shows up in production when the dataset grows. By then, it's too late—users are already experiencing slow responses.

This is why we need tests that verify query counts. This is why we need observability to surface latency problems. This is why we need to understand how ORMs work under the hood.

Abstractions are powerful, but they hide cost. Hibernate makes it easy to work with objects, but it doesn't make the database queries free. We have to be deliberate about fetch strategies.

---

## The pattern – Prefetch, don't lazy-load in loops

The fix is simple: prefetch related entities before you iterate over them. Don't rely on lazy loading inside loops or streams.

If you're fetching a collection of entities and you know you'll need their relationships, fetch them eagerly. Use `join fetch` in JPQL, or call a separate query to preload the relationships.

This pattern applies to any ORM, not just Hibernate. Entity Framework in .NET has the same problem. ActiveRecord in Rails has the same problem. The solution is always the same: prefetch.

---

## What we're not covering – Second-level caches and database tuning

We're not covering second-level caches in this episode. Caching is a separate concern. The N+1 problem should be fixed at the query level, not hidden behind a cache.

We're also not covering database-specific tuning—indexes, query plans, connection pooling. Those are important, but they don't fix the N+1 problem. If you're executing 101 queries instead of 2, no amount of indexing will make it fast.

Fix the query pattern first. Then optimize the database.

---

## Closing – Measure, fix, verify

The N+1 problem is common, invisible, and fixable. The pattern is always the same: measure with observability, diagnose with SQL logging, fix with eager fetching, and verify with tests.

Observability showed us the latency spike. SQL logging showed us the N+1 queries. Eager fetching fixed the problem. Tests prevent regressions.

This is how you build systems that perform well in production. Not by guessing, not by premature optimization, but by measuring, fixing, and verifying.

In the next episode, we'll look at another performance topic: virtual threads and how they change the way we think about concurrency in Java. But we can only do that because we have observability and tests in place to measure the impact.

You can't fix what you can't see. You can't trust what you can't verify. Now we can do both.
