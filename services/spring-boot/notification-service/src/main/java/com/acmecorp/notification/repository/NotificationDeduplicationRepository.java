package com.acmecorp.notification.repository;

import com.acmecorp.notification.domain.NotificationDeduplication;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface NotificationDeduplicationRepository extends JpaRepository<NotificationDeduplication, Long> {

    boolean existsByMessageFingerprint(String messageFingerprint);

    Optional<NotificationDeduplication> findByMessageFingerprint(String messageFingerprint);
}
