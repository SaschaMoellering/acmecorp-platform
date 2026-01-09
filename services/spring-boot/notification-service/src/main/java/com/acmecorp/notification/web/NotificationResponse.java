package com.acmecorp.notification.web;

import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;

import java.time.Instant;

public class NotificationResponse {

    private final Long id;
    private final String recipient;
    private final String message;
    private final NotificationType type;
    private final NotificationStatus status;
    private final Instant createdAt;
    private final Instant sentAt;
    private final String orderNumber;
    private final String invoiceNumber;

    public NotificationResponse(Long id,
                                String recipient,
                                String message,
                                NotificationType type,
                                NotificationStatus status,
                                Instant createdAt,
                                Instant sentAt,
                                String orderNumber,
                                String invoiceNumber) {
        this.id = id;
        this.recipient = recipient;
        this.message = message;
        this.type = type;
        this.status = status;
        this.createdAt = createdAt;
        this.sentAt = sentAt;
        this.orderNumber = orderNumber;
        this.invoiceNumber = invoiceNumber;
    }

    public Long getId() {
        return id;
    }

    public String getRecipient() {
        return recipient;
    }

    public String getMessage() {
        return message;
    }

    public NotificationType getType() {
        return type;
    }

    public NotificationStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getSentAt() {
        return sentAt;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public String getInvoiceNumber() {
        return invoiceNumber;
    }

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
