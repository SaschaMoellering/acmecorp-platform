package com.acmecorp.orders.web;

import com.acmecorp.orders.domain.OrderStatus;
import javax.validation.constraints.Email;
import javax.validation.constraints.NotEmpty;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Positive;

import java.util.List;

public class OrderRequest {

    @NotNull
    @Email
    private String customerEmail;

    @NotEmpty
    private List<Item> items;

    private OrderStatus status;

    public OrderRequest() {
    }

    public OrderRequest(String customerEmail, List<Item> items, OrderStatus status) {
        this.customerEmail = customerEmail;
        this.items = items;
        this.status = status;
    }

    public String getCustomerEmail() {
        return customerEmail;
    }

    public void setCustomerEmail(String customerEmail) {
        this.customerEmail = customerEmail;
    }

    public List<Item> getItems() {
        return items;
    }

    public void setItems(List<Item> items) {
        this.items = items;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public void setStatus(OrderStatus status) {
        this.status = status;
    }

    public static class Item {

        @NotNull
        private String productId;

        @Positive
        private int quantity;

        public Item() {
        }

        public Item(String productId, int quantity) {
            this.productId = productId;
            this.quantity = quantity;
        }

        public String getProductId() {
            return productId;
        }

        public void setProductId(String productId) {
            this.productId = productId;
        }

        public int getQuantity() {
            return quantity;
        }

        public void setQuantity(int quantity) {
            this.quantity = quantity;
        }
    }
}
