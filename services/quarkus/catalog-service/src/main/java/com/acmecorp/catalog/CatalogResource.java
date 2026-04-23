package com.acmecorp.catalog;

import com.acmecorp.catalog.service.CatalogService;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;
import java.util.UUID;

@Path("/api/catalog")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class CatalogResource {

    private final CatalogService catalogService;

    public CatalogResource(CatalogService catalogService) {
        this.catalogService = catalogService;
    }

    @GET
    public List<Product> list(@QueryParam("category") String category,
                              @QueryParam("search") String search) {
        return catalogService.listProducts(category, search);
    }

    @GET
    @Path("/{id}")
    public Product get(@PathParam("id") UUID id) {
        return catalogService.getProductById(id);
    }

    @POST
    public Product create(@Valid ProductRequest request) {
        return catalogService.createProduct(request);
    }

    @PUT
    @Path("/{id}")
    public Product update(@PathParam("id") UUID id, @Valid ProductRequest request) {
        return catalogService.updateProduct(id, request);
    }

    @DELETE
    @Path("/{id}")
    public void delete(@PathParam("id") UUID id) {
        // The product remains queryable by id after DELETE, but is removed from active list results.
        catalogService.deleteProduct(id);
    }

    @POST
    @Path("/seed")
    public List<Product> seed() {
        return catalogService.seedProducts();
    }

    @GET
    @Path("/status")
    public Object status() {
        return java.util.Map.of("service", "catalog-service", "status", "OK");
    }
}
