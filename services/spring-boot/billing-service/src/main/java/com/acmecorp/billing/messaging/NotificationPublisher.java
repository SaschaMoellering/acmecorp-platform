package com.acmecorp.billing.messaging;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.HashMap;

@Component
public class NotificationPublisher {

    private final RabbitTemplate rabbitTemplate;

    public NotificationPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void sendInvoicePaid(String recipient, String invoiceNumber) {
        var payload = new HashMap<String, Object>();
        payload.put("recipient", recipient);
        payload.put("message", "Your invoice " + invoiceNumber + " has been paid.");
        payload.put("type", "INVOICE_PAID");
        payload.put("invoiceNumber", invoiceNumber);
        payload.put("timestamp", Instant.now().toString());
        rabbitTemplate.convertAndSend("notifications-exchange", "notifications.key", payload);
    }
}