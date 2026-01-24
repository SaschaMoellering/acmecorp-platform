package com.acmecorp.catalog;

import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;
import java.util.UUID;

@Path("/api/catalog")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class CatalogResource {

    private final ProductRepository productRepository;
    private static final java.time.Instant SEED_INSTANT = java.time.Instant.parse("2024-01-01T00:00:00Z");

    public CatalogResource(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @GET
    public List<Product> list(@QueryParam("category") String category,
                              @QueryParam("search") String search) {
        return productRepository.active(category, search);
    }

    @GET
    @Path("/{id}")
    public Product get(@PathParam("id") UUID id) {
        return productRepository.findByIdOptional(id)
                .orElseThrow(() -> new NotFoundException("Product not found"));
    }

    @POST
    @Transactional
    public Product create(@Valid ProductRequest request) {
        Product product = new Product();
        applyRequest(product, request);
        product.persist();
        return product;
    }

    @PUT
    @Path("/{id}")
    @Transactional
    public Product update(@PathParam("id") UUID id, @Valid ProductRequest request) {
        Product product = get(id);
        applyRequest(product, request);
        product.persist();
        return product;
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public void delete(@PathParam("id") UUID id) {
        Product product = get(id);
        product.active = false;
        product.persist();
    }

    @POST
    @Path("/seed")
    @Transactional
    public List<Product> seed() {
        List<Product> products = List.of(
                build(UUID.fromString("11111111-1111-1111-1111-111111111111"), "ACME-STREAM-001", "Acme Streamer Pro", "HD streaming subscription with analytics dashboard", "SAAS", new java.math.BigDecimal("49.00")),
                build(UUID.fromString("22222222-2222-2222-2222-222222222222"), "ACME-ALERT-001", "Alerting Add-on", "Real-time alerts and incidents with on-call rotation", "ADDON", new java.math.BigDecimal("19.00")),
                build(UUID.fromString("33333333-3333-3333-3333-333333333333"), "ACME-STORAGE-010", "Secure Storage 1TB", "Encrypted cloud storage for media and backups", "STORAGE", new java.math.BigDecimal("29.00")),
                build(UUID.fromString("44444444-4444-4444-4444-444444444444"), "ACME-AI-001", "AI Insights", "Predictive recommendations for digital storefronts", "SAAS", new java.math.BigDecimal("59.00"))
        );
        List<UUID> ids = products.stream().map(p -> p.id).collect(java.util.stream.Collectors.toList());
        productRepository.delete("id in ?1", ids);
        products.forEach(productRepository::persist);
        return products;
    }

    @GET
    @Path("/status")
    public Object status() {
        return java.util.Map.of("service", "catalog-service", "status", "OK");
    }

    private void applyRequest(Product product, ProductRequest request) {
        product.sku = request.sku();
        product.name = request.name();
        product.description = request.description();
        product.price = request.price();
        product.currency = request.currency();
        product.category = request.category();
        product.active = request.active();
        product.updatedAt = java.time.Instant.now();
    }

    private Product build(UUID id, String sku, String name, String description, String category, java.math.BigDecimal price) {
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
