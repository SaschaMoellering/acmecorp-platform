package com.acmecorp.orders.repository;

import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.List;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Long>, JpaSpecificationExecutor<Order> {
    List<Order> findTop10ByOrderByCreatedAtDesc();
    long countByStatus(OrderStatus status);

    Optional<Order> findTopByOrderNumberStartingWithOrderByOrderNumberDesc(String prefix);
}
