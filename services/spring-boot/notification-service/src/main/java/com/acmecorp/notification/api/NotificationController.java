package com.acmecorp.notification.api;

import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;
import com.acmecorp.notification.service.NotificationService;
import com.acmecorp.notification.web.NotificationRequest;
import com.acmecorp.notification.web.NotificationResponse;
import com.acmecorp.notification.web.PageResponse;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/notification")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of(
                "service", "notification-service",
                "status", "OK"
        );
    }

    @PostMapping("/send")
    public Map<String, Object> send(@Valid @RequestBody NotificationRequest request) {
        notificationService.enqueue(request);
        return Map.of("status", "QUEUED", "recipient", request.recipient());
    }

    @GetMapping
    public PageResponse<NotificationResponse> list(@RequestParam(name = "recipient", required = false) String recipient,
                                                   @RequestParam(name = "status", required = false) NotificationStatus status,
                                                   @RequestParam(name = "type", required = false) NotificationType type,
                                                   @RequestParam(name = "page", defaultValue = "0") int page,
                                                   @RequestParam(name = "size", defaultValue = "20") int size) {
        var notifications = notificationService.list(recipient, status, type, page, size);
        var responses = notifications.getContent().stream().map(NotificationResponse::from).toList();
        return PageResponse.from(new PageImpl<>(responses, PageRequest.of(page, size), notifications.getTotalElements()));
    }

    @GetMapping("/{id}")
    public NotificationResponse get(@PathVariable Long id) {
        return notificationService.toResponse(notificationService.get(id));
    }
}
