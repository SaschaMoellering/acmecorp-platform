package com.acmecorp.orders.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

@ConfigurationProperties(prefix = "acmecorp.postgres")
public class OrdersPostgresProperties {

    private String host;
    private int port = 5432;
    private String database;
    private String username;
    private String region;
    private final IamAuth iamAuth = new IamAuth();

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public String getDatabase() {
        return database;
    }

    public void setDatabase(String database) {
        this.database = database;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getRegion() {
        return region;
    }

    public void setRegion(String region) {
        this.region = region;
    }

    public IamAuth getIamAuth() {
        return iamAuth;
    }

    public static class IamAuth {
        private boolean enabled;
        private Duration maxLifetime = Duration.ofMinutes(9);
        private int poolSize = 10;

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public Duration getMaxLifetime() {
            return maxLifetime;
        }

        public void setMaxLifetime(Duration maxLifetime) {
            this.maxLifetime = maxLifetime;
        }

        public int getPoolSize() {
            return poolSize;
        }

        public void setPoolSize(int poolSize) {
            this.poolSize = poolSize;
        }
    }
}
