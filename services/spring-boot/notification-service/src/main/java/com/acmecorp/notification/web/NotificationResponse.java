package com.acmecorp.notification.web;

import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;

import java.time.Instant;

public record NotificationResponse(Long id,
                                   String recipient,
                                   String message,
                                   NotificationType type,
                                   NotificationStatus status,
                                   Instant createdAt,
                                   Instant sentAt,
                                   String orderNumber,
                                   String invoiceNumber) {

    public static NotificationResponse from(Notification notification) {
        return new NotificationResponse(
                notification.getId(),
                notification.getRecipient(),
                notification.getMessage(),
                notification.getType(),
                notification.getStatus(),
                notification.getCreatedAt(),
                notification.getSentAt(),
                notification.getOrderNumber(),
                notification.getInvoiceNumber()
        );
    }
}
