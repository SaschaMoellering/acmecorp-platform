package com.acmecorp.billing.messaging;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class NotificationPublisherTest {

    @Mock
    private RabbitTemplate rabbitTemplate;

    @InjectMocks
    private NotificationPublisher notificationPublisher;

    @Test
    void shouldSendInvoicePaidNotification() {
        // When
        notificationPublisher.sendInvoicePaid("test@example.com", "INV-2025-00001");

        // Then
        verify(rabbitTemplate).convertAndSend(
            eq("notifications-exchange"),
            eq("notifications.key"),
            any(Map.class)
        );
    }
}