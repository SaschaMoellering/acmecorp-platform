package com.acmecorp.analytics.config;

import org.apache.coyote.ProtocolHandler;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;

import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Configuration
@EnableAsync
@ConditionalOnProperty(name = "spring.threads.virtual.enabled", havingValue = "true")
public class VirtualThreadsConfig implements AsyncConfigurer {

    @Bean(destroyMethod = "shutdown")
    public ExecutorService virtualThreadExecutor() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }

    @Bean
    public WebServerFactoryCustomizer<TomcatServletWebServerFactory> virtualThreadTomcatCustomizer(
            ExecutorService virtualThreadExecutor) {

        return factory -> factory.addProtocolHandlerCustomizers((ProtocolHandler protocolHandler) ->
                protocolHandler.setExecutor(virtualThreadExecutor)
        );
    }

    @Override
    public Executor getAsyncExecutor() {
        return virtualThreadExecutor();
    }
}