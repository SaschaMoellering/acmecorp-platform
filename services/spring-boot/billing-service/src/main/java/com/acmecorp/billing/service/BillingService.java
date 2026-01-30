package com.acmecorp.billing.service;

import com.acmecorp.billing.client.AnalyticsClient;
import com.acmecorp.billing.domain.Invoice;
import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.domain.Payment;
import com.acmecorp.billing.domain.PaymentMethod;
import com.acmecorp.billing.repository.InvoiceRepository;
import com.acmecorp.billing.repository.PaymentRepository;
import com.acmecorp.billing.web.InvoiceRequest;
import com.acmecorp.billing.web.InvoiceResponse;
import com.acmecorp.billing.web.PaymentRequest;
import org.springframework.context.annotation.Profile;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.time.Year;
import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

@Service
@Profile("!buildpack")
public class BillingService {

    private final InvoiceRepository invoiceRepository;
    private final PaymentRepository paymentRepository;
    private final AnalyticsClient analyticsClient;

    private final AtomicInteger sequenceCounter = new AtomicInteger(0);
    private int counterYear = Year.now().getValue();
    private boolean counterInitialized = false;

    public BillingService(InvoiceRepository invoiceRepository,
                          PaymentRepository paymentRepository,
                          AnalyticsClient analyticsClient) {
        this.invoiceRepository = invoiceRepository;
        this.paymentRepository = paymentRepository;
        this.analyticsClient = analyticsClient;
    }

    @Transactional
    public Invoice createInvoice(InvoiceRequest request) {
        Invoice invoice = new Invoice();
        invoice.setInvoiceNumber(generateInvoiceNumber());
        invoice.setOrderId(request.orderId());
        invoice.setOrderNumber(request.orderNumber());
        invoice.setCustomerEmail(request.customerEmail());
        invoice.setAmount(request.amount());
        invoice.setCurrency(request.currency());
        invoice.setStatus(InvoiceStatus.OPEN);
        invoice.setCreatedAt(Instant.now());
        invoice.setUpdatedAt(invoice.getCreatedAt());
        Invoice saved = invoiceRepository.save(invoice);
        analyticsClient.track("billing.invoice.created", request.asMetadata(saved.getId()));
        return saved;
    }

    @Transactional(readOnly = true)
    public Invoice getInvoice(Long id) {
        return invoiceRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Invoice not found"));
    }

    @Transactional(readOnly = true)
    public Page<Invoice> listInvoices(String customerEmail, InvoiceStatus status, Long orderId, int page, int size) {
        Specification<Invoice> spec = Specification.where(null);
        if (customerEmail != null && !customerEmail.isBlank()) {
            spec = spec.and((root, query, cb) -> cb.like(cb.lower(root.get("customerEmail")), "%" + customerEmail.toLowerCase(Locale.ROOT) + "%"));
        }
        if (status != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("status"), status));
        }
        if (orderId != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("orderId"), orderId));
        }
        return invoiceRepository.findAll(spec, PageRequest.of(page, size));
    }

    @Transactional
    public Invoice pay(Long id, PaymentRequest request) {
        Invoice invoice = getInvoice(id);
        if (invoice.getStatus() == InvoiceStatus.PAID) {
            return invoice;
        }
        if (invoice.getStatus() != InvoiceStatus.OPEN) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only OPEN invoices can be paid");
        }
        Payment payment = new Payment();
        payment.setPaymentMethod(request.paymentMethod() != null ? request.paymentMethod() : PaymentMethod.DEMO);
        payment.setAmount(request.amount() != null ? request.amount() : invoice.getAmount());
        payment.setTimestamp(Instant.now());
        invoice.addPayment(payment);
        invoice.setStatus(InvoiceStatus.PAID);
        invoice.setUpdatedAt(Instant.now());
        Invoice saved = invoiceRepository.save(invoice);
        paymentRepository.save(payment);
        analyticsClient.track("billing.invoice.paid", request.asMetadata(saved.getId(), saved.getInvoiceNumber()));
        return saved;
    }

    private synchronized String generateInvoiceNumber() {
        int currentYear = Year.now().getValue();
        String prefix = "INV-" + currentYear + "-";

        if (!counterInitialized || currentYear != counterYear) {
            int maxExisting = invoiceRepository.findTopByInvoiceNumberStartingWithOrderByInvoiceNumberDesc(prefix)
                    .map(Invoice::getInvoiceNumber)
                    .map(this::parseSequenceNumber)
                    .orElse(0);
            sequenceCounter.set(maxExisting);
            counterYear = currentYear;
            counterInitialized = true;
        }

        int sequence = sequenceCounter.incrementAndGet();
        return prefix + String.format("%05d", sequence);
    }

    private int parseSequenceNumber(String invoiceNumber) {
        // Expected format: INV-YYYY-XXXXX
        String[] parts = invoiceNumber.split("-");
        if (parts.length == 3) {
            try {
                return Integer.parseInt(parts[2]);
            } catch (NumberFormatException ignored) {
                // fall through
            }
        }
        return 0;
    }

    @Transactional(readOnly = true)
    public InvoiceResponse toResponse(Invoice invoice) {
        return InvoiceResponse.from(invoice);
    }
}
