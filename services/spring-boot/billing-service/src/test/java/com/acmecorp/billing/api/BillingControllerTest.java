package com.acmecorp.billing.api;

import com.acmecorp.billing.domain.Invoice;
import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.service.BillingService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(BillingController.class)
class BillingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
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
}
