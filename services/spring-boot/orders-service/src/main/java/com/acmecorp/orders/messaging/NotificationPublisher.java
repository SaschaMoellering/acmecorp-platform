package com.acmecorp.orders.messaging;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Component
public class NotificationPublisher {

    private final RabbitTemplate rabbitTemplate;

    public NotificationPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void sendOrderConfirmation(String recipient, String orderNumber) {
        var payload = new HashMap<String, Object>();
        payload.put("recipient", recipient);
        payload.put("message", "Your order " + orderNumber + " has been confirmed.");
        payload.put("type", "ORDER_CONFIRMATION");
        payload.put("orderNumber", orderNumber);
        payload.put("timestamp", Instant.now().toString());
        rabbitTemplate.convertAndSend("notifications-exchange", "notifications.key", payload);
    }
}
