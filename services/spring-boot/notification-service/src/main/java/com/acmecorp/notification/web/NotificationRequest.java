package com.acmecorp.notification.web;

import com.acmecorp.notification.domain.NotificationType;
import javax.validation.constraints.Email;
import javax.validation.constraints.NotBlank;

public class NotificationRequest {

    @Email
    private String recipient;

    @NotBlank
    private String message;

    private NotificationType type;
    private String orderNumber;
    private String invoiceNumber;

    public NotificationRequest() {
    }

    public NotificationRequest(String recipient,
                               String message,
                               NotificationType type,
                               String orderNumber,
                               String invoiceNumber) {
        this.recipient = recipient;
        this.message = message;
        this.type = type;
        this.orderNumber = orderNumber;
        this.invoiceNumber = invoiceNumber;
    }

    public String getRecipient() {
        return recipient;
    }

    public void setRecipient(String recipient) {
        this.recipient = recipient;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public NotificationType getType() {
        return type;
    }

    public void setType(NotificationType type) {
        this.type = type;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public void setOrderNumber(String orderNumber) {
        this.orderNumber = orderNumber;
    }

    public String getInvoiceNumber() {
        return invoiceNumber;
    }

    public void setInvoiceNumber(String invoiceNumber) {
        this.invoiceNumber = invoiceNumber;
    }
}
