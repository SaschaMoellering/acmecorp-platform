package com.acmecorp.catalog.service;

import com.acmecorp.catalog.Product;
import com.acmecorp.catalog.ProductRepository;
import com.acmecorp.catalog.ProductRequest;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.NotFoundException;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@ApplicationScoped
public class CatalogService {

    private static final Instant SEED_INSTANT = Instant.parse("2024-01-01T00:00:00Z");

    private final ProductRepository productRepository;
    private final CatalogProductCache productCache;
    private final CatalogCacheInvalidationScheduler cacheInvalidationScheduler;
    private final CatalogCacheMetrics cacheMetrics;

    public CatalogService(ProductRepository productRepository,
                          CatalogProductCache productCache,
                          CatalogCacheInvalidationScheduler cacheInvalidationScheduler,
                          CatalogCacheMetrics cacheMetrics) {
        this.productRepository = productRepository;
        this.productCache = productCache;
        this.cacheInvalidationScheduler = cacheInvalidationScheduler;
        this.cacheMetrics = cacheMetrics;
    }

    public List<Product> listProducts(String category, String search) {
        return productRepository.active(category, search);
    }

    // Only single-product reads are cached. Filtered list queries stay database-backed to keep cache keys,
    // invalidation behavior, and course explanations explicit.
    // This path can return inactive products after logical deactivation because it looks up by primary key.
    public Product getProductById(UUID id) {
        return cacheMetrics.recordCachedRead(() -> productCache.get(id)
                .orElseGet(() -> loadProductFromDatasource(id)));
    }

    @Transactional
    public Product createProduct(ProductRequest request) {
        Product product = new Product();
        applyRequest(product, request);
        product.persist();
        cacheInvalidationScheduler.invalidateProductAfterCommit(product.id);
        return product;
    }

    @Transactional
    public Product updateProduct(UUID id, ProductRequest request) {
        Product product = requireManagedProduct(id);
        applyRequest(product, request);
        product.persist();
        cacheInvalidationScheduler.invalidateProductAfterCommit(id);
        return product;
    }

    @Transactional
    public void deleteProduct(UUID id) {
        Product product = requireManagedProduct(id);
        // DELETE is implemented as logical deactivation so course examples can still inspect the product by id.
        product.active = false;
        product.persist();
        cacheInvalidationScheduler.invalidateProductAfterCommit(id);
    }

    @Transactional
    public List<Product> seedProducts() {
        List<Product> products = List.of(
                build(UUID.fromString("11111111-1111-1111-1111-111111111111"), "ACME-STREAM-001", "Acme Streamer Pro", "HD streaming subscription with analytics dashboard", "SAAS", new BigDecimal("49.00")),
                build(UUID.fromString("22222222-2222-2222-2222-222222222222"), "ACME-ALERT-001", "Alerting Add-on", "Real-time alerts and incidents with on-call rotation", "ADDON", new BigDecimal("19.00")),
                build(UUID.fromString("33333333-3333-3333-3333-333333333333"), "ACME-STORAGE-010", "Secure Storage 1TB", "Encrypted cloud storage for media and backups", "STORAGE", new BigDecimal("29.00")),
                build(UUID.fromString("44444444-4444-4444-4444-444444444444"), "ACME-AI-001", "AI Insights", "Predictive recommendations for digital storefronts", "SAAS", new BigDecimal("59.00"))
        );
        List<UUID> ids = products.stream().map(p -> p.id).collect(Collectors.toList());
        productRepository.delete("id in ?1", ids);
        products.forEach(productRepository::persist);
        cacheInvalidationScheduler.invalidateProductsAfterCommit(ids);
        return products;
    }

    private Product loadProductFromDatasource(UUID id) {
        cacheMetrics.recordDatasourceRead();
        Product product = productRepository.findByIdOptional(id)
                .orElseThrow(() -> new NotFoundException("Product not found"));
        productCache.put(product);
        return product;
    }

    private Product requireManagedProduct(UUID id) {
        return productRepository.findByIdOptional(id)
                .orElseThrow(() -> new NotFoundException("Product not found"));
    }

    private void applyRequest(Product product, ProductRequest request) {
        product.sku = request.sku();
        product.name = request.name();
        product.description = request.description();
        product.price = request.price();
        product.currency = request.currency();
        product.category = request.category();
        product.active = request.active();
        product.updatedAt = Instant.now();
    }

    private Product build(UUID id, String sku, String name, String description, String category, BigDecimal price) {
        Product product = new Product();
        product.id = id;
        product.sku = sku;
        product.name = name;
        product.description = description;
        product.category = category;
        product.price = price;
        product.currency = "USD";
        product.active = true;
        product.createdAt = SEED_INSTANT;
        product.updatedAt = SEED_INSTANT;
        return product;
    }
}
