package com.acmecorp.orders.config;

import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariPoolMXBean;
import jakarta.annotation.PostConstruct;
import javax.sql.DataSource;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.Connection;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.connection.CachingConnectionFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class CracDataSourceLifecycle {

    private static final Logger log = LoggerFactory.getLogger(CracDataSourceLifecycle.class);

    private final DataSource dataSource;
    private final ObjectProvider<CachingConnectionFactory> rabbitConnectionFactoryProvider;
    private final Environment environment;

    public CracDataSourceLifecycle(
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
                new Class<?>[] { resourceClass },
                handler
            );

            Method registerMethod = contextClass.getMethod("register", resourceClass);
            registerMethod.invoke(globalContext, resourceProxy);
            log.info("Registered CRaC datasource lifecycle resource");
        } catch (ClassNotFoundException ex) {
            log.info("CRaC classes are not present; skipping datasource lifecycle registration");
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to register CRaC datasource lifecycle resource", ex);
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
            return "CracDataSourceLifecycleProxy";
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
        if (!(dataSource instanceof HikariDataSource hikariDataSource)) {
            log.info("Skipping CRaC datasource lifecycle: datasource is not Hikari ({})", dataSource.getClass().getName());
            return;
        }

        log.info("Preparing datasource for CRaC checkpoint");

        try {
            HikariPoolMXBean pool = hikariDataSource.getHikariPoolMXBean();
            if (pool != null) {
                pool.suspendPool();
                pool.softEvictConnections();
                waitForNoActiveConnections(pool);
            }
            resetRabbitConnection();
            log.info("Datasource prepared for checkpoint");
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to prepare datasource for CRaC checkpoint", ex);
        }
    }

    private void afterRestore() {
        if (!(dataSource instanceof HikariDataSource hikariDataSource)) {
            return;
        }

        try {
            resetRabbitConnection();
            HikariPoolMXBean pool = hikariDataSource.getHikariPoolMXBean();
            if (pool != null) {
                pool.resumePool();
            }
            try (Connection connection = hikariDataSource.getConnection()) {
                // Force connection re-establishment after restore.
            }
            log.info("Datasource reinitialized after CRaC restore");
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to reinitialize datasource after CRaC restore", ex);
        }
    }

    private boolean isCracHookEnabled() {
        boolean enabled = environment.getProperty("CRAC_ENABLED", Boolean.class,
            environment.getProperty("crac.enabled", Boolean.class, false));

        if (!enabled) {
            return false;
        }

        String mode = environment.getProperty("CRAC_MODE", "off");
        boolean activeMode = "checkpoint".equalsIgnoreCase(mode) || "restore".equalsIgnoreCase(mode);
        if (!activeMode) {
            log.info("CRAC_ENABLED=true but CRAC_MODE={} so datasource lifecycle hook is not activated", mode);
        }
        return activeMode;
    }

    private void waitForNoActiveConnections(HikariPoolMXBean pool) throws InterruptedException {
        for (int i = 0; i < 50; i++) {
            if (pool.getActiveConnections() == 0) {
                return;
            }
            Thread.sleep(100);
        }

        log.warn(
            "Hikari pool still has connections before checkpoint (active={}, idle={}, total={})",
            pool.getActiveConnections(), pool.getIdleConnections(), pool.getTotalConnections()
        );
    }

    private void resetRabbitConnection() {
        CachingConnectionFactory rabbitConnectionFactory = rabbitConnectionFactoryProvider.getIfAvailable();
        if (rabbitConnectionFactory != null) {
            rabbitConnectionFactory.resetConnection();
        }
    }
}
