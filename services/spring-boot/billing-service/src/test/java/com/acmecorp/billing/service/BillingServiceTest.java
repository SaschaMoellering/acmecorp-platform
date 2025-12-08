package com.acmecorp.billing.service;

import com.acmecorp.billing.client.AnalyticsClient;
import com.acmecorp.billing.domain.Invoice;
import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.domain.Payment;
import com.acmecorp.billing.domain.PaymentMethod;
import com.acmecorp.billing.repository.InvoiceRepository;
import com.acmecorp.billing.repository.PaymentRepository;
import com.acmecorp.billing.web.PaymentRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BillingServiceTest {

    @Mock
    private InvoiceRepository invoiceRepository;

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private AnalyticsClient analyticsClient;

    @InjectMocks
    private BillingService billingService;

    @Test
    void payShouldMarkInvoicePaidAndTrack() {
        Invoice invoice = new Invoice();
        invoice.setInvoiceNumber("INV-100");
        invoice.setStatus(InvoiceStatus.OPEN);
        invoice.setAmount(new BigDecimal("25.00"));
        invoice.setCurrency("USD");
        invoice.setCreatedAt(Instant.now());
        invoice.setUpdatedAt(invoice.getCreatedAt());

        when(invoiceRepository.findById(1L)).thenReturn(Optional.of(invoice));
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> {
            Invoice toSave = inv.getArgument(0);
            if (toSave.getId() == null) {
                // simulate persistence assigning an id
                var field = Invoice.class.getDeclaredField("id");
                field.setAccessible(true);
                field.set(toSave, 1L);
            }
            return toSave;
        });

        PaymentRequest request = new PaymentRequest(new BigDecimal("25.00"), PaymentMethod.CREDIT_CARD);
        Invoice paid = billingService.pay(1L, request);

        assertThat(paid.getStatus()).isEqualTo(InvoiceStatus.PAID);
        verify(paymentRepository).save(any(Payment.class));
        verify(analyticsClient).track(eq("billing.invoice.paid"), anyMap());
    }

    @Test
    void payShouldRejectNonOpenInvoice() {
        Invoice invoice = new Invoice();
        invoice.setInvoiceNumber("INV-200");
        invoice.setStatus(InvoiceStatus.CANCELLED);
        invoice.setAmount(new BigDecimal("30.00"));
        invoice.setCurrency("USD");
        invoice.setCreatedAt(Instant.now());
        invoice.setUpdatedAt(invoice.getCreatedAt());

        when(invoiceRepository.findById(2L)).thenReturn(Optional.of(invoice));

        assertThrows(ResponseStatusException.class,
                () -> billingService.pay(2L, new PaymentRequest(new BigDecimal("30.00"), PaymentMethod.DEMO)));
        verify(analyticsClient, never()).track(anyString(), anyMap());
        verify(paymentRepository, never()).save(any(Payment.class));
    }
}
