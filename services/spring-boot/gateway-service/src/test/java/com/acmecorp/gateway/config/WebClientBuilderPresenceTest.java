package com.acmecorp.gateway.config;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.reactive.function.client.WebClient;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("docker")
class WebClientBuilderPresenceTest {
    @Autowired
    private ApplicationContext context;

    @Test
    void webClientBuilderBeanIsAvailable() {
        assertThat(context.getBean(WebClient.Builder.class)).isNotNull();
    }
}
