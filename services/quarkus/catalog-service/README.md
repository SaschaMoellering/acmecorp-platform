# Catalog Service Cache Notes

This service uses Redis-backed caching for one read path only:

- `GET /api/catalog/{id}`

The cache is implemented in `CatalogService.getProductById(...)` and backed by `CatalogProductCache`.

## What Is Cached

Only single-product lookups by id are cached.

This is intentional:

- the `get by id` path is stable and read-heavy
- the key shape is simple and bounded
- invalidation stays explicit on product mutations
- filtered list queries would require more cache keys and more complicated invalidation for limited teaching value

List reads (`GET /api/catalog`) remain database-backed and only return `active = true` products.

## Redis Key Shape

Product cache entries use this key pattern:

- `catalog:product:{productId}`

Examples:

- `catalog:product:11111111-1111-1111-1111-111111111111`

The cached payload is a JSON snapshot of the product fields stored in `CachedProduct`.

## Invalidation Behavior

Cache invalidation is explicit and per product id:

- `createProduct`: invalidates the new product key so the next `get by id` is a cold read and repopulates Redis
- `updateProduct`: invalidates the product key after persisting the updated state
- `deleteProduct`: invalidates the product key after logical deactivation
- `seedProducts`: invalidates the seeded product ids after replacing those rows

The service does not try to refresh the cache during writes. It removes the entry and lets the next read repopulate it from the datasource. That keeps the write path simple and keeps cold vs warm reads observable in metrics.

## Delete Semantics

`DELETE /api/catalog/{id}` is a logical deactivation, not a hard delete.

Current behavior:

- the row stays in the database
- `active` is set to `false`
- list queries stop returning the product because they only read `active = true`
- `get by id` can still return the product, including after it has been deactivated
- a later `get by id` can repopulate Redis with the inactive product state

This is why the cache tests verify two different outcomes after delete:

- the active list no longer includes the product
- `get by id` still returns the product with `active=false`

## Cache Metrics

The service emits low-cardinality Micrometer metrics tagged with:

- `cache=catalog`
- `operation=getProductById`

Metrics:

- `acmecorp.catalog.cache.hits`: Redis contained the product and the datasource was avoided
- `acmecorp.catalog.cache.misses`: Redis did not satisfy the lookup, so the service had to fall back to the datasource path
- `acmecorp.catalog.cache.puts`: a datasource-backed read populated Redis
- `acmecorp.catalog.cache.errors`: Redis read, write, or invalidation failed
- `acmecorp.catalog.datasource.reads`: the datasource was queried because the cache could not satisfy `getProductById`
- `acmecorp.catalog.cache.read`: timer for the full cached read path, including Redis lookup and datasource fallback when needed

## How To Read The Metrics

Cold reads usually look like this:

- `cache.misses` increases
- `datasource.reads` increases
- `cache.puts` increases
- `cache.hits` does not increase for that request

Warm reads usually look like this:

- `cache.hits` increases
- `datasource.reads` does not increase
- `cache.puts` does not increase

If Redis is unavailable or a cache operation fails:

- `cache.errors` increases
- the request should still succeed if the datasource read succeeds
- `datasource.reads` increases because the cache did not satisfy the lookup

Operationally, the useful interpretation is:

- increasing hits with flat datasource reads means the cache is absorbing repeated lookups
- increasing misses and puts after writes is expected because invalidation forces the next read to repopulate
- increasing errors means Redis is unhealthy or the cache payload is unreadable, and the service is running in fallback mode
