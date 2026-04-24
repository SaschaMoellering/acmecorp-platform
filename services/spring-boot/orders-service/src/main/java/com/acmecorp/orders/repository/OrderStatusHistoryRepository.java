package com.acmecorp.orders.repository;

import com.acmecorp.orders.domain.OrderStatusHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;

public interface OrderStatusHistoryRepository extends JpaRepository<OrderStatusHistory, Long> {

    List<OrderStatusHistory> findByOrderIdOrderByChangedAtAsc(Long orderId);

    @Transactional
    void deleteByOrderId(Long orderId);

    @Transactional
    void deleteByOrderIdIn(Collection<Long> orderIds);
}
