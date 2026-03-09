package com.acmecorp.analytics.config;

import org.apache.coyote.ProtocolHandler;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.embedded.tomcat.TomcatProtocolHandlerCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Configuration
@EnableAsync
@ConditionalOnProperty(name = "spring.threads.virtual.enabled", havingValue = "true")
public class VirtualThreadsConfig implements AsyncConfigurer {

    @Bean(destroyMethod = "shutdown")
    public ExecutorService virtualThreadExecutor() {
        try {
            Method factory = Executors.class.getMethod("newVirtualThreadPerTaskExecutor");
            return (ExecutorService) factory.invoke(null);
        } catch (NoSuchMethodException e) {
            return Executors.newCachedThreadPool();
        } catch (IllegalAccessException | InvocationTargetException e) {
            throw new IllegalStateException("Failed to create virtual-thread executor", e);
        }
    }

    @Bean
    public TomcatProtocolHandlerCustomizer<ProtocolHandler> virtualThreadTomcatCustomizer(
            ExecutorService virtualThreadExecutor) {
        return protocolHandler -> protocolHandler.setExecutor(virtualThreadExecutor);
    }

    @Override
    public Executor getAsyncExecutor() {
        return virtualThreadExecutor();
    }
}
