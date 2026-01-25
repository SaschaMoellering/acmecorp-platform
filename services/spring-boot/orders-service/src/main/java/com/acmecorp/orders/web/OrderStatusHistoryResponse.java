package com.acmecorp.orders.web;

import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.domain.OrderStatusHistory;

import java.time.Instant;

public class OrderStatusHistoryResponse {

    private final Long id;
    private final Long orderId;
    private final OrderStatus oldStatus;
    private final OrderStatus newStatus;
    private final String reason;
    private final Instant changedAt;

    public OrderStatusHistoryResponse(Long id,
                                      Long orderId,
                                      OrderStatus oldStatus,
                                      OrderStatus newStatus,
                                      String reason,
                                      Instant changedAt) {
        this.id = id;
        this.orderId = orderId;
        this.oldStatus = oldStatus;
        this.newStatus = newStatus;
        this.reason = reason;
        this.changedAt = changedAt;
    }

    public static OrderStatusHistoryResponse from(OrderStatusHistory history) {
        return new OrderStatusHistoryResponse(
                history.getId(),
                history.getOrderId(),
                history.getOldStatus(),
                history.getNewStatus(),
                history.getReason(),
                history.getChangedAt()
        );
    }

    public Long getId() {
        return id;
    }

    public Long getOrderId() {
        return orderId;
    }

    public OrderStatus getOldStatus() {
        return oldStatus;
    }

    public OrderStatus getNewStatus() {
        return newStatus;
    }

    public String getReason() {
        return reason;
    }

    public Instant getChangedAt() {
        return changedAt;
    }
}
