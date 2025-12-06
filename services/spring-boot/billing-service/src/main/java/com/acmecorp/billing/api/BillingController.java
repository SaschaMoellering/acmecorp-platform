package com.acmecorp.billing.api;

import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.service.BillingService;
import com.acmecorp.billing.web.InvoiceRequest;
import com.acmecorp.billing.web.InvoiceResponse;
import com.acmecorp.billing.web.PaymentRequest;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/billing")
public class BillingController {

    private final BillingService billingService;

    public BillingController(BillingService billingService) {
        this.billingService = billingService;
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of(
                "service", "billing-service",
                "status", "OK"
        );
    }

    @PostMapping("/invoices")
    public InvoiceResponse createInvoice(@Valid @RequestBody InvoiceRequest request) {
        return billingService.toResponse(billingService.createInvoice(request));
    }

    @GetMapping("/invoices/{id}")
    public InvoiceResponse getInvoice(@PathVariable Long id) {
        return billingService.toResponse(billingService.getInvoice(id));
    }

    @GetMapping("/invoices")
    public Page<InvoiceResponse> listInvoices(@RequestParam(required = false) String customerEmail,
                                              @RequestParam(required = false) InvoiceStatus status,
                                              @RequestParam(required = false) Long orderId,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "20") int size) {
        var invoices = billingService.listInvoices(customerEmail, status, orderId, page, size);
        var responses = invoices.getContent().stream().map(InvoiceResponse::from).toList();
        return new PageImpl<>(responses, PageRequest.of(page, size), invoices.getTotalElements());
    }

    @PostMapping("/invoices/{id}/pay")
    public InvoiceResponse pay(@PathVariable Long id, @Valid @RequestBody(required = false) PaymentRequest request) {
        PaymentRequest payload = request != null ? request : new PaymentRequest(null, null);
        return billingService.toResponse(billingService.pay(id, payload));
    }
}
