package com.acmecorp.notification.web;

import com.acmecorp.notification.domain.NotificationType;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record NotificationRequest(
        @Email String recipient,
        @NotBlank String message,
        NotificationType type,
        String orderNumber,
        String invoiceNumber
) {
}
