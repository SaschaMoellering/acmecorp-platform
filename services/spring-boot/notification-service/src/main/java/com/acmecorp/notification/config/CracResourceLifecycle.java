package com.acmecorp.notification.config;

import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariPoolMXBean;
import jakarta.annotation.PostConstruct;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.connection.CachingConnectionFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class CracResourceLifecycle {

    private static final Logger log = LoggerFactory.getLogger(CracResourceLifecycle.class);

    private final DataSource dataSource;
    private final ObjectProvider<CachingConnectionFactory> rabbitConnectionFactoryProvider;
    private final Environment environment;

    public CracResourceLifecycle(
        DataSource dataSource,
        ObjectProvider<CachingConnectionFactory> rabbitConnectionFactoryProvider,
        Environment environment
    ) {
        this.dataSource = dataSource;
        this.rabbitConnectionFactoryProvider = rabbitConnectionFactoryProvider;
        this.environment = environment;
    }

    @PostConstruct
    void registerCracResource() {
        if (!isCracHookEnabled()) {
            return;
        }

        try {
            Class<?> coreClass = Class.forName("org.crac.Core");
            Class<?> contextClass = Class.forName("org.crac.Context");
            Class<?> resourceClass = Class.forName("org.crac.Resource");

            Object globalContext = coreClass.getMethod("getGlobalContext").invoke(null);
            InvocationHandler handler = this::handleCracCallback;
            Object resourceProxy = Proxy.newProxyInstance(
                resourceClass.getClassLoader(),
                new Class<?>[] {resourceClass},
                handler
            );

            Method registerMethod = contextClass.getMethod("register", resourceClass);
            registerMethod.invoke(globalContext, resourceProxy);
            log.info("Registered CRaC resource lifecycle");
        } catch (ClassNotFoundException ex) {
            log.info("CRaC classes are not present; skipping resource lifecycle registration");
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to register CRaC resource lifecycle", ex);
        }
    }

    private Object handleCracCallback(Object proxy, Method method, Object[] args) {
        String methodName = method.getName();
        if ("beforeCheckpoint".equals(methodName)) {
            beforeCheckpoint();
            return null;
        }
        if ("afterRestore".equals(methodName)) {
            afterRestore();
            return null;
        }

        if ("toString".equals(methodName)) {
            return "CracResourceLifecycleProxy";
        }
        if ("hashCode".equals(methodName)) {
            return System.identityHashCode(proxy);
        }
        if ("equals".equals(methodName)) {
            return proxy == args[0];
        }
        return null;
    }

    private void beforeCheckpoint() {
        if (dataSource instanceof HikariDataSource hikariDataSource) {
            try {
                HikariPoolMXBean pool = hikariDataSource.getHikariPoolMXBean();
                if (pool != null) {
                    pool.suspendPool();
                    pool.softEvictConnections();
                    waitForNoActiveConnections(pool);
                }
            } catch (Exception ex) {
                throw new IllegalStateException("Failed to suspend datasource for CRaC checkpoint", ex);
            }
        }

        resetRabbitConnection();
        log.info("CRaC checkpoint resources prepared");
    }

    private void afterRestore() {
        if (dataSource instanceof HikariDataSource hikariDataSource) {
            try {
                HikariPoolMXBean pool = hikariDataSource.getHikariPoolMXBean();
                if (pool != null) {
                    pool.resumePool();
                }
                try (Connection connection = hikariDataSource.getConnection()) {
                    // Force connection re-establishment after restore.
                }
            } catch (Exception ex) {
                throw new IllegalStateException("Failed to resume datasource after CRaC restore", ex);
            }
        }

        resetRabbitConnection();
        log.info("CRaC restore resources resumed");
    }

    private void resetRabbitConnection() {
        CachingConnectionFactory rabbitConnectionFactory = rabbitConnectionFactoryProvider.getIfAvailable();
        if (rabbitConnectionFactory != null) {
            rabbitConnectionFactory.resetConnection();
        }
    }

    private boolean isCracHookEnabled() {
        boolean enabled = environment.getProperty("CRAC_ENABLED", Boolean.class,
            environment.getProperty("crac.enabled", Boolean.class, false));

        if (!enabled) {
            return false;
        }

        String mode = environment.getProperty("CRAC_MODE", "off");
        return "checkpoint".equalsIgnoreCase(mode) || "restore".equalsIgnoreCase(mode);
    }

    private void waitForNoActiveConnections(HikariPoolMXBean pool) throws InterruptedException {
        for (int i = 0; i < 50; i++) {
            if (pool.getActiveConnections() == 0) {
                return;
            }
            Thread.sleep(100);
        }
    }
}
