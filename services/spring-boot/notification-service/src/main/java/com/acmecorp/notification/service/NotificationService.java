package com.acmecorp.notification.service;

import com.acmecorp.notification.config.RabbitConfig;
import com.acmecorp.notification.client.AnalyticsClient;
import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;
import com.acmecorp.notification.repository.NotificationRepository;
import com.acmecorp.notification.web.NotificationRequest;
import com.acmecorp.notification.web.NotificationResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationRepository notificationRepository;
    private final RabbitTemplate rabbitTemplate;
    private final AnalyticsClient analyticsClient;

    @Value("${acmecorp.messaging.notification.demo.fail-on-recipient:}")
    private String failOnRecipient;

    public NotificationService(NotificationRepository notificationRepository,
                               RabbitTemplate rabbitTemplate,
                               AnalyticsClient analyticsClient) {
        this.notificationRepository = notificationRepository;
        this.rabbitTemplate = rabbitTemplate;
        this.analyticsClient = analyticsClient;
    }

    @Transactional
    public void enqueue(NotificationRequest request) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("recipient", request.recipient());
        payload.put("message", request.message());
        payload.put("type", request.type() != null ? request.type().name() : NotificationType.GENERIC.name());
        payload.put("timestamp", Instant.now().toString());
        if (request.orderNumber() != null) {
            payload.put("orderNumber", request.orderNumber());
        }
        if (request.invoiceNumber() != null) {
            payload.put("invoiceNumber", request.invoiceNumber());
        }
        rabbitTemplate.convertAndSend(RabbitConfig.EXCHANGE_NAME, RabbitConfig.ROUTING_KEY, payload);
    }

    @Transactional
    public void handleMessage(Map<String, Object> payload) {
        String recipient = (String) payload.getOrDefault("recipient", "unknown@acme.test");
        if (StringUtils.hasText(failOnRecipient) && failOnRecipient.equalsIgnoreCase(recipient)) {
            log.warn("Forcing notification processing failure for recipient {} to demonstrate retry and DLQ handling", recipient);
            throw new IllegalStateException("Forced notification failure for recipient " + recipient);
        }

        Notification notification = new Notification();
        notification.setRecipient(recipient);
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
        log.info("Notification {} sent successfully for recipient {}", saved.getId(), saved.getRecipient());
    }

    @Transactional(readOnly = true)
    public Notification get(Long id) {
        return notificationRepository.findById(id)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND, "Notification not found"));
    }

    @Transactional(readOnly = true)
    public Page<Notification> list(String recipient, NotificationStatus status, NotificationType type, int page, int size) {
        Specification<Notification> spec = Specification.where(null);
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
