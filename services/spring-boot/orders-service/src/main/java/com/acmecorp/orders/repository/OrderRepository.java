package com.acmecorp.orders.repository;

import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.Set;

public interface OrderRepository extends JpaRepository<Order, Long>, JpaSpecificationExecutor<Order> {
    List<Order> findTop10ByOrderByCreatedAtDesc();
    long countByStatus(OrderStatus status);

    Optional<Order> findTopByOrderNumberStartingWithOrderByOrderNumberDesc(String prefix);
    List<Order> findByOrderNumberIn(List<String> orderNumbers);

    @Query("""
        select distinct o
        from Order o
        left join fetch o.items
        where o.id in :ids
        order by o.createdAt desc
    """)
    List<Order> findAllWithItemsByIds(@Param("ids") Set<Long> ids);
}
