package com.acmecorp.orders.repository;

import com.acmecorp.orders.domain.OrderStatusHistory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface OrderStatusHistoryRepository extends JpaRepository<OrderStatusHistory, Long> {
    List<OrderStatusHistory> findByOrderIdOrderByChangedAtAsc(Long orderId);
    void deleteByOrderIdIn(List<Long> orderIds);
}
