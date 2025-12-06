package com.acmecorp.catalog;

import io.quarkus.hibernate.orm.panache.PanacheRepositoryBase;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class ProductRepository implements PanacheRepositoryBase<Product, UUID> {

    public List<Product> active(String category, String search) {
        StringBuilder query = new StringBuilder("active = true");
        if (category != null && !category.isBlank()) {
            query.append(" and lower(category) = ?1");
            if (search != null && !search.isBlank()) {
                query.append(" and (lower(name) like ?2 or lower(description) like ?2)");
                return list(query.toString(), category.toLowerCase(), "%" + search.toLowerCase() + "%");
            }
            return list(query.toString(), category.toLowerCase());
        }
        if (search != null && !search.isBlank()) {
            query.append(" and (lower(name) like ?1 or lower(description) like ?1)");
            return list(query.toString(), "%" + search.toLowerCase() + "%");
        }
        return list(query.toString());
    }
}
