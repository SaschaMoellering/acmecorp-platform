package com.acmecorp.billing.api;

import com.acmecorp.billing.domain.Invoice;
import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.service.BillingService;
import com.acmecorp.billing.web.PaymentRequest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(BillingController.class)
class BillingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private BillingService billingService;

    @Test
    void statusEndpointShouldReturnOk() throws Exception {
        mockMvc.perform(get("/api/billing/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("billing-service"));
    }

    @Test
    void invoicesListShouldReturnPage() throws Exception {
        Invoice invoice = new Invoice();
        invoice.setInvoiceNumber("INV-1");
        invoice.setStatus(InvoiceStatus.OPEN);
        invoice.setAmount(new BigDecimal("20.00"));
        invoice.setCurrency("USD");
        invoice.setCreatedAt(Instant.now());
        invoice.setUpdatedAt(Instant.now());
        Mockito.when(billingService.listInvoices(null, null, null, 0, 20))
                .thenReturn(new PageImpl<>(List.of(invoice)));

        mockMvc.perform(get("/api/billing/invoices"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].invoiceNumber").value("INV-1"));
    }

    @Test
    void getInvoiceShouldReturnNotFound() throws Exception {
        Mockito.when(billingService.getInvoice(99L)).thenThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND, "Invoice not found"));

        mockMvc.perform(get("/api/billing/invoices/99"))
                .andExpect(status().isNotFound());
    }

    @Test
    void createInvoiceShouldReturnInvoiceResponse() throws Exception {
        Invoice invoice = new Invoice();
        invoice.setInvoiceNumber("INV-3");
        invoice.setStatus(InvoiceStatus.OPEN);
        invoice.setAmount(new BigDecimal("45.50"));
        invoice.setCurrency("USD");
        invoice.setCreatedAt(Instant.now());
        invoice.setUpdatedAt(invoice.getCreatedAt());
        Mockito.when(billingService.createInvoice(Mockito.any())).thenReturn(invoice);
        Mockito.when(billingService.toResponse(invoice)).thenCallRealMethod();

        mockMvc.perform(post("/api/billing/invoices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "orderId": 10,
                                  "orderNumber": "ORD-10",
                                  "customerEmail": "billing@acme.test",
                                  "amount": 45.50,
                                  "currency": "USD"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.invoiceNumber").value("INV-3"))
                .andExpect(jsonPath("$.status").value("OPEN"));
    }

    @Test
    void payInvoiceShouldReturnUpdatedResponse() throws Exception {
        Invoice invoice = new Invoice();
        invoice.setInvoiceNumber("INV-2");
        invoice.setStatus(InvoiceStatus.PAID);
        invoice.setAmount(new BigDecimal("30.00"));
        invoice.setCurrency("USD");
        invoice.setUpdatedAt(Instant.now());
        Mockito.when(billingService.pay(Mockito.eq(5L), Mockito.any(PaymentRequest.class))).thenReturn(invoice);
        Mockito.when(billingService.toResponse(invoice)).thenCallRealMethod();

        mockMvc.perform(post("/api/billing/invoices/5/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"paymentMethod\":\"CREDIT_CARD\",\"amount\":30.00}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.invoiceNumber").value("INV-2"))
                .andExpect(jsonPath("$.status").value("PAID"));
    }

    @Test
    void payInvoiceShouldReturnBadRequestForNonOpenInvoice() throws Exception {
        Mockito.when(billingService.pay(Mockito.eq(15L), Mockito.any(PaymentRequest.class)))
                .thenThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST, "Only OPEN invoices can be paid"));

        mockMvc.perform(post("/api/billing/invoices/15/pay")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"paymentMethod\":\"CREDIT_CARD\",\"amount\":15.00}"))
                .andExpect(status().isBadRequest());
    }
}
