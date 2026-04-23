package com.acmecorp.notification.messaging;

import com.acmecorp.notification.config.RabbitConfig;
import com.acmecorp.notification.service.NotificationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.retry.support.RetrySynchronizationManager;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class NotificationListener {

    private static final Logger log = LoggerFactory.getLogger(NotificationListener.class);

    private final NotificationService notificationService;

    public NotificationListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @RabbitListener(
            queues = RabbitConfig.QUEUE_NAME,
            containerFactory = "notificationListenerContainerFactory"
    )
    public void onMessage(Map<String, Object> payload) {
        int attempt = 1;
        var context = RetrySynchronizationManager.getContext();
        if (context != null) {
            attempt = context.getRetryCount() + 1;
        }
        log.info("Processing notification message attempt {} for recipient {}", attempt, payload.get("recipient"));
        notificationService.handleMessage(payload);
    }
}
