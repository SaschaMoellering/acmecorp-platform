package com.acmecorp.orders.web;

import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.domain.OrderStatusHistory;

import java.time.Instant;

public record OrderStatusHistoryResponse(Long id,
                                         Long orderId,
                                         OrderStatus oldStatus,
                                         OrderStatus newStatus,
                                         String reason,
                                         Instant changedAt) {

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
}
