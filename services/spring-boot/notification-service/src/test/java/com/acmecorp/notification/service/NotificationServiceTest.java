package com.acmecorp.notification.service;

import com.acmecorp.notification.client.AnalyticsClient;
import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;
import com.acmecorp.notification.repository.NotificationRepository;
import com.acmecorp.notification.web.NotificationRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import java.time.Instant;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository notificationRepository;

    @Mock
    private RabbitTemplate rabbitTemplate;

    @Mock
    private AnalyticsClient analyticsClient;

    @InjectMocks
    private NotificationService notificationService;

    @Test
    void enqueueShouldPublishToBroker() {
        NotificationRequest request = new NotificationRequest("queue@acme.test", "hello queue", NotificationType.ORDER_CONFIRMATION, "ORD-1", "INV-1");

        notificationService.enqueue(request);

        ArgumentCaptor<Map<String, Object>> payload = ArgumentCaptor.forClass(Map.class);
        verify(rabbitTemplate).convertAndSend(eq("notifications-exchange"), eq("notifications.key"), payload.capture());
        assertThat(payload.getValue().get("recipient")).isEqualTo("queue@acme.test");
        assertThat(payload.getValue().get("message")).isEqualTo("hello queue");
        assertThat(payload.getValue().get("type")).isEqualTo(NotificationType.ORDER_CONFIRMATION.name());
    }

    @Test
    void handleMessageShouldPersistAndTrack() {
        Notification persisted = new Notification();
        persisted.setRecipient("persist@acme.test");
        persisted.setMessage("payload");
        persisted.setType(NotificationType.ORDER_CONFIRMATION);
        persisted.setStatus(NotificationStatus.QUEUED);
        persisted.setCreatedAt(Instant.now());

        when(notificationRepository.save(any(Notification.class))).thenAnswer(inv -> {
            Notification n = inv.getArgument(0);
            var field = Notification.class.getDeclaredField("id");
            field.setAccessible(true);
            field.set(n, 10L);
            return n;
        }).thenReturn(persisted);

        notificationService.handleMessage(Map.of(
                "recipient", "persist@acme.test",
                "message", "payload",
                "type", "ORDER_CONFIRMATION"
        ));

        verify(notificationRepository, times(2)).save(any(Notification.class));
        verify(analyticsClient).track(eq("notification.sent"), anyMap());
    }
}
