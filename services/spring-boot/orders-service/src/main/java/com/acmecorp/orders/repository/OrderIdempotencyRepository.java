package com.acmecorp.orders.repository;

import com.acmecorp.orders.domain.OrderIdempotency;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface OrderIdempotencyRepository extends JpaRepository<OrderIdempotency, Long> {
    Optional<OrderIdempotency> findByIdempotencyKey(String idempotencyKey);
    void deleteByOrderIdIn(List<Long> orderIds);
}
