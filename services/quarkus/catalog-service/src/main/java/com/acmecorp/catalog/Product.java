package com.acmecorp.catalog;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

@Entity
@Table(name = "products")
public class Product extends PanacheEntityBase {

    @Id
    public UUID id;

    @Column(nullable = false, unique = true)
    public String sku;

    @Column(nullable = false)
    public String name;

    @Column(length = 1024)
    public String description;

    @Column(nullable = false, precision = 15, scale = 2)
    public BigDecimal price;

    @Column(nullable = false, length = 5)
    public String currency;

    @Column(nullable = false)
    public String category;

    @Column(nullable = false)
    public boolean active = true;

    @Column(nullable = false)
    public Instant createdAt;

    @Column(nullable = false)
    public Instant updatedAt;

    @PrePersist
    public void prePersist() {
        Instant now = Instant.now();
        if (id == null) {
            id = UUID.randomUUID();
        }
        createdAt = now;
        updatedAt = now;
    }
}
