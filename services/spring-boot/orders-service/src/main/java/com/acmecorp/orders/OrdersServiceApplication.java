package com.acmecorp.orders;

import com.acmecorp.orders.startup.StartupTimeline;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class OrdersServiceApplication {
    public static void main(String[] args) {
        StartupTimeline.markJvmMainStart();
        SpringApplication.run(OrdersServiceApplication.class, args);
    }
}
