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
}
