package com.acmecorp.notification.service;

import com.acmecorp.notification.client.AnalyticsClient;
import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;
import com.acmecorp.notification.repository.NotificationRepository;
import com.acmecorp.notification.web.NotificationRequest;
import com.acmecorp.notification.web.NotificationResponse;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.util.Locale;
import java.util.Map;

@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final RabbitTemplate rabbitTemplate;
    private final AnalyticsClient analyticsClient;

    public NotificationService(NotificationRepository notificationRepository,
                               RabbitTemplate rabbitTemplate,
                               AnalyticsClient analyticsClient) {
        this.notificationRepository = notificationRepository;
        this.rabbitTemplate = rabbitTemplate;
        this.analyticsClient = analyticsClient;
    }

    @Transactional
    public void enqueue(NotificationRequest request) {
        var payload = Map.of(
                "recipient", request.recipient(),
                "message", request.message(),
                "type", request.type() != null ? request.type().name() : NotificationType.GENERIC.name(),
                "orderNumber", request.orderNumber(),
                "invoiceNumber", request.invoiceNumber(),
                "timestamp", Instant.now().toString()
        );
        rabbitTemplate.convertAndSend("notifications-exchange", "notifications.key", payload);
    }

    @Transactional
    public void handleMessage(Map<String, Object> payload) {
        Notification notification = new Notification();
        notification.setRecipient((String) payload.getOrDefault("recipient", "unknown@acme.test"));
        notification.setMessage((String) payload.getOrDefault("message", "No message"));
        notification.setOrderNumber((String) payload.getOrDefault("orderNumber", null));
        notification.setInvoiceNumber((String) payload.getOrDefault("invoiceNumber", null));
        String type = (String) payload.getOrDefault("type", NotificationType.GENERIC.name());
        notification.setType(NotificationType.valueOf(type));
        notification.setStatus(NotificationStatus.QUEUED);
        notification.setCreatedAt(Instant.now());
        Notification saved = notificationRepository.save(notification);

        // Simulate sending
        saved.setStatus(NotificationStatus.SENT);
        saved.setSentAt(Instant.now());
        notificationRepository.save(saved);
        analyticsClient.track("notification.sent", Map.of("notificationId", saved.getId(), "type", saved.getType().name()));
    }

    @Transactional(readOnly = true)
    public Notification get(Long id) {
        return notificationRepository.findById(id)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND, "Notification not found"));
    }

    @Transactional(readOnly = true)
    public Page<Notification> list(String recipient, NotificationStatus status, NotificationType type, int page, int size) {
        Specification<Notification> spec = (root, query, cb) -> cb.conjunction();
        if (StringUtils.hasText(recipient)) {
            spec = spec.and((root, query, cb) -> cb.like(cb.lower(root.get("recipient")), "%" + recipient.toLowerCase(Locale.ROOT) + "%"));
        }
        if (status != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("status"), status));
        }
        if (type != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("type"), type));
        }
        return notificationRepository.findAll(spec, PageRequest.of(page, size));
    }

    @Transactional(readOnly = true)
    public NotificationResponse toResponse(Notification notification) {
        return NotificationResponse.from(notification);
    }
}
