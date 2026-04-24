package com.acmecorp.notification.service;

import com.acmecorp.notification.config.RabbitConfig;
import com.acmecorp.notification.client.AnalyticsClient;
import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationDeduplication;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;
import com.acmecorp.notification.repository.NotificationDeduplicationRepository;
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

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationRepository notificationRepository;
    private final NotificationDeduplicationRepository deduplicationRepository;
    private final RabbitTemplate rabbitTemplate;
    private final AnalyticsClient analyticsClient;

    @Value("${acmecorp.messaging.notification.demo.fail-on-recipient:}")
    private String failOnRecipient;

    public NotificationService(NotificationRepository notificationRepository,
                               NotificationDeduplicationRepository deduplicationRepository,
                               RabbitTemplate rabbitTemplate,
                               AnalyticsClient analyticsClient) {
        this.notificationRepository = notificationRepository;
        this.deduplicationRepository = deduplicationRepository;
        this.rabbitTemplate = rabbitTemplate;
        this.analyticsClient = analyticsClient;
    }

    @Transactional
    public void enqueue(NotificationRequest request) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("recipient", request.getRecipient());
        payload.put("message", request.getMessage());
        payload.put("type", request.getType() != null ? request.getType().name() : NotificationType.GENERIC.name());
        payload.put("timestamp", Instant.now().toString());
        if (request.getOrderNumber() != null) {
            payload.put("orderNumber", request.getOrderNumber());
        }
        if (request.getInvoiceNumber() != null) {
            payload.put("invoiceNumber", request.getInvoiceNumber());
        }
        rabbitTemplate.convertAndSend(RabbitConfig.EXCHANGE_NAME, RabbitConfig.ROUTING_KEY, payload);
    }

    @Transactional
    public void handleMessage(Map<String, Object> payload) {
        String recipient = (String) payload.getOrDefault("recipient", "unknown@acme.test");
        if (StringUtils.hasText(failOnRecipient) && failOnRecipient.equalsIgnoreCase(recipient)) {
            log.warn("Forcing notification processing failure for configured demo recipient");
            throw new IllegalStateException("Forced notification failure for recipient " + recipient);
        }

        String orderNumber = (String) payload.getOrDefault("orderNumber", null);
        String invoiceNumber = (String) payload.getOrDefault("invoiceNumber", null);
        String type = (String) payload.getOrDefault("type", NotificationType.GENERIC.name());
        String message = (String) payload.getOrDefault("message", "No message");
        String fingerprint = messageFingerprint(recipient, message, type, orderNumber, invoiceNumber);

        if (deduplicationRepository.existsByMessageFingerprint(fingerprint)) {
            log.info("Duplicate notification message detected for fingerprint {}", fingerprint);
            return;
        }

        Notification notification = new Notification();
        notification.setRecipient(recipient);
        notification.setMessage(message);
        notification.setOrderNumber(orderNumber);
        notification.setInvoiceNumber(invoiceNumber);
        notification.setType(NotificationType.valueOf(type));
        notification.setStatus(NotificationStatus.QUEUED);
        notification.setCreatedAt(Instant.now());
        Notification saved = notificationRepository.save(notification);

        NotificationDeduplication dedup = new NotificationDeduplication();
        dedup.setMessageFingerprint(fingerprint);
        dedup.setNotification(saved);
        dedup.setCreatedAt(Instant.now());
        deduplicationRepository.save(dedup);

        // Simulate sending
        saved.setStatus(NotificationStatus.SENT);
        saved.setSentAt(Instant.now());
        notificationRepository.save(saved);
        analyticsClient.track("notification.sent", Map.of("notificationId", saved.getId(), "type", saved.getType().name()));
    }

    private String messageFingerprint(String recipient, String message, String type, String orderNumber, String invoiceNumber) {
        String raw = String.join("|",
                recipient != null ? recipient : "",
                message != null ? message : "",
                type != null ? type : "",
                orderNumber != null ? orderNumber : "",
                invoiceNumber != null ? invoiceNumber : ""
        );
        return sha256(raw);
    }

    private String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to compute message fingerprint", ex);
        }
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
