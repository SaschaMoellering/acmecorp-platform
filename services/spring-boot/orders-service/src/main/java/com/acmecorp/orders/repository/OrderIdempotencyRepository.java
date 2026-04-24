package com.acmecorp.orders.repository;

import com.acmecorp.orders.domain.OrderIdempotency;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.Optional;

public interface OrderIdempotencyRepository extends JpaRepository<OrderIdempotency, Long> {

    Optional<OrderIdempotency> findByIdempotencyKey(String idempotencyKey);

    @Transactional
    void deleteByOrderId(Long orderId);

    @Transactional
    void deleteByOrderIdIn(Collection<Long> orderIds);
}
