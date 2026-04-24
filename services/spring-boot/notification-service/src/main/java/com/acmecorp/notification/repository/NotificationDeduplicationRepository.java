package com.acmecorp.notification.repository;

import com.acmecorp.notification.domain.NotificationDeduplication;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationDeduplicationRepository extends JpaRepository<NotificationDeduplication, Long> {

    boolean existsByMessageFingerprint(String messageFingerprint);
}
