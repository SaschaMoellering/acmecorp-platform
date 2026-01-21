package com.acmecorp.orders.messaging;

import com.acmecorp.orders.config.RabbitConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.AmqpException;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.HashMap;

@Component
public class NotificationPublisher {

    private static final Logger log = LoggerFactory.getLogger(NotificationPublisher.class);

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
        try {
            rabbitTemplate.convertAndSend(RabbitConfig.EXCHANGE_NAME, RabbitConfig.ROUTING_KEY, payload);
        } catch (AmqpException ex) {
            log.error("Failed to publish order confirmation for order {}", orderNumber, ex);
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Notification broker unavailable");
        }
    }
}
