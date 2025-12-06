package com.acmecorp.billing.repository;

import com.acmecorp.billing.domain.Payment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
}
