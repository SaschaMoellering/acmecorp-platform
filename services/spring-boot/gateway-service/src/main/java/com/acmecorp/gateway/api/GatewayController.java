package com.acmecorp.gateway.api;

import com.acmecorp.gateway.service.GatewayService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/gateway")
public class GatewayController {

    private final GatewayService gatewayService;

    public GatewayController(GatewayService gatewayService) {
        this.gatewayService = gatewayService;
    }

    @GetMapping(path = "/orders", produces = MediaType.APPLICATION_JSON_VALUE)
    public Mono<String> proxyOrdersStatus() {
        return gatewayService.proxyOrdersStatus();
    }

    @GetMapping(path = "/orders/latest", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<GatewayService.OrderSummary> latestOrders() {
        return gatewayService.latestOrders();
    }

    @GetMapping(path = "/orders/{id}", produces = MediaType.APPLICATION_JSON_VALUE)
    public GatewayService.OrderWithInvoice orderDetails(@PathVariable Long id) {
        return gatewayService.orderDetails(id);
    }

    @GetMapping(path = "/catalog", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<GatewayService.ProductSummary> catalog(@RequestParam(required = false) String category,
                                                       @RequestParam(required = false) String search) {
        return gatewayService.catalog(category, search);
    }

    @GetMapping(path = "/catalog/raw", produces = MediaType.APPLICATION_JSON_VALUE)
    public Mono<String> proxyCatalog() {
        return gatewayService.proxyCatalogRaw();
    }

    @GetMapping(path = "/analytics/counters", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Long> analyticsCounters() {
        return gatewayService.analyticsCounters();
    }

    @GetMapping(path = "/system/status", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<GatewayService.SystemStatus> systemStatus() {
        return gatewayService.systemStatus();
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of("service", "gateway-service", "status", "OK");
    }
}
