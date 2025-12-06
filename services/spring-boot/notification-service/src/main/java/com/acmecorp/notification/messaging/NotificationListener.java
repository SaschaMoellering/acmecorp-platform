package com.acmecorp.notification.messaging;

import com.acmecorp.notification.service.NotificationService;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class NotificationListener {

    private final NotificationService notificationService;

    public NotificationListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @RabbitListener(queues = "notifications-queue")
    public void onMessage(Map<String, Object> payload) {
        notificationService.handleMessage(payload);
    }
}
