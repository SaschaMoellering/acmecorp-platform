package com.acmecorp.orders.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.rds.RdsUtilities;
import software.amazon.awssdk.services.rds.model.GenerateAuthenticationTokenRequest;

import javax.sql.DataSource;
import java.time.Duration;
import java.util.function.Supplier;

@Configuration
@ConditionalOnProperty(prefix = "acmecorp.postgres.iam-auth", name = "enabled", havingValue = "true")
@EnableConfigurationProperties(OrdersPostgresProperties.class)
public class PostgresIamDataSourceConfiguration {

    @Bean
    public RdsUtilities rdsUtilities(OrdersPostgresProperties properties) {
        return RdsUtilities.builder()
                .region(Region.of(properties.getRegion()))
                .build();
    }

    @Bean
    @Primary
    public DataSource iamDataSource(OrdersPostgresProperties properties, RdsUtilities utilities) {
        OrdersPostgresProperties.IamAuth iamAuth = properties.getIamAuth();
        Supplier<String> tokenSupplier = () -> utilities.generateAuthenticationToken(
                GenerateAuthenticationTokenRequest.builder()
                        .hostname(properties.getHost())
                        .port(properties.getPort())
                        .username(properties.getUsername())
                        .build());

        IamAuthenticatedDataSource pgDataSource = new IamAuthenticatedDataSource(tokenSupplier);
        pgDataSource.setServerNames(new String[]{properties.getHost()});
        pgDataSource.setPortNumbers(new int[]{properties.getPort()});
        pgDataSource.setDatabaseName(properties.getDatabase());
        pgDataSource.setUser(properties.getUsername());
        pgDataSource.setSsl(true);

        HikariConfig hikariConfig = new HikariConfig();
        hikariConfig.setDataSource(pgDataSource);
        hikariConfig.setMaximumPoolSize(iamAuth.getPoolSize());
        Duration maxLifetime = iamAuth.getMaxLifetime();
        hikariConfig.setMaxLifetime(maxLifetime.toMillis());
        hikariConfig.setConnectionTimeout(30_000);
        hikariConfig.setValidationTimeout(5_000);
        hikariConfig.setConnectionTestQuery("SELECT 1");
        hikariConfig.setMinimumIdle(1);
        hikariConfig.setPoolName("orders-iam-pool");

        return new HikariDataSource(hikariConfig);
    }
}
