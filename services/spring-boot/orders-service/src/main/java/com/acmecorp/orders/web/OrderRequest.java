package com.acmecorp.orders.web;

import com.acmecorp.orders.domain.OrderStatus;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.util.List;

public record OrderRequest(
        @NotNull @Email String customerEmail,
        @NotEmpty List<Item> items,
        OrderStatus status
) {

    public record Item(@NotNull String productId, @Positive int quantity) {
    }
}
