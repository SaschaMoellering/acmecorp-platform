package com.acmecorp.orders.web;

import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderItem;
import com.acmecorp.orders.domain.OrderStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

public class OrderResponse {

    private final Long id;
    private final String orderNumber;
    private final String customerEmail;
    private final OrderStatus status;
    private final BigDecimal totalAmount;
    private final String currency;
    private final Instant createdAt;
    private final Instant updatedAt;
    private final List<OrderItemResponse> items;

    public OrderResponse(Long id,
                         String orderNumber,
                         String customerEmail,
                         OrderStatus status,
                         BigDecimal totalAmount,
                         String currency,
                         Instant createdAt,
                         Instant updatedAt,
                         List<OrderItemResponse> items) {
        this.id = id;
        this.orderNumber = orderNumber;
        this.customerEmail = customerEmail;
        this.status = status;
        this.totalAmount = totalAmount;
        this.currency = currency;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.items = items;
    }

    public Long getId() {
        return id;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public String getCustomerEmail() {
        return customerEmail;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public BigDecimal getTotalAmount() {
        return totalAmount;
    }

    public String getCurrency() {
        return currency;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public List<OrderItemResponse> getItems() {
        return items;
    }

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
                order.getItems().stream()
                        .map(OrderItemResponse::from)
                        .collect(Collectors.toList())
        );
    }

    public static class OrderItemResponse {

        private final Long id;
        private final String productId;
        private final String productName;
        private final BigDecimal unitPrice;
        private final int quantity;
        private final BigDecimal lineTotal;

        public OrderItemResponse(Long id,
                                 String productId,
                                 String productName,
                                 BigDecimal unitPrice,
                                 int quantity,
                                 BigDecimal lineTotal) {
            this.id = id;
            this.productId = productId;
            this.productName = productName;
            this.unitPrice = unitPrice;
            this.quantity = quantity;
            this.lineTotal = lineTotal;
        }

        public Long getId() {
            return id;
        }

        public String getProductId() {
            return productId;
        }

        public String getProductName() {
            return productName;
        }

        public BigDecimal getUnitPrice() {
            return unitPrice;
        }

        public int getQuantity() {
            return quantity;
        }

        public BigDecimal getLineTotal() {
            return lineTotal;
        }

        public static OrderItemResponse from(OrderItem item) {
            return new OrderItemResponse(
                    item.getId(),
                    item.getProductId(),
                    item.getProductName(),
                    item.getUnitPrice(),
                    item.getQuantity(),
                    item.getLineTotal()
            );
        }
    }
}
