package com.acmecorp.notification.repository;

import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.domain.NotificationType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface NotificationRepository extends JpaRepository<Notification, Long>, JpaSpecificationExecutor<Notification> {
    long countByStatus(NotificationStatus status);
    long countByType(NotificationType type);
}
