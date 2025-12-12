package com.acmecorp.catalog.config;

import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigProvider;
import org.postgresql.ds.PGSimpleDataSource;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.rds.RdsUtilities;
import software.amazon.awssdk.services.rds.model.GenerateAuthenticationTokenRequest;

import java.sql.Connection;
import java.sql.SQLException;

public class IamAuthenticatedDataSource extends PGSimpleDataSource {

    private static final Config CONFIG = ConfigProvider.getConfig();
    private static final boolean IAM_ENABLED = CONFIG
            .getOptionalValue("acmecorp.postgres.iam-auth.enabled", Boolean.class)
            .orElse(false);

    private static final String HOST = CONFIG
            .getOptionalValue("acmecorp.postgres.host", String.class)
            .orElse("postgres");
    private static final int PORT = CONFIG
            .getOptionalValue("acmecorp.postgres.port", Integer.class)
            .orElse(5432);
    private static final String USER = CONFIG
            .getOptionalValue("acmecorp.postgres.username", String.class)
            .orElse("acmecorp");
    private static final Region REGION = Region.of(CONFIG
            .getOptionalValue("acmecorp.postgres.region", String.class)
            .orElseGet(() -> CONFIG.getOptionalValue("AWS_REGION", String.class).orElse("eu-west-1")));

    private static final RdsUtilities UTILITIES = IAM_ENABLED
            ? RdsUtilities.builder().region(REGION).build()
            : null;

    private volatile String baselinePassword;

    @Override
    public void setPassword(String password) {
        super.setPassword(password);
        this.baselinePassword = password;
    }

    private String nextPassword() {
        if (!IAM_ENABLED || UTILITIES == null) {
            return baselinePassword;
        }

        return UTILITIES.generateAuthenticationToken(
                GenerateAuthenticationTokenRequest.builder()
                        .hostname(HOST)
                        .port(PORT)
                        .username(USER)
                        .build());
    }

    @Override
    public Connection getConnection() throws SQLException {
        super.setPassword(nextPassword());
        return super.getConnection();
    }

    @Override
    public Connection getConnection(String username, String password) throws SQLException {
        super.setPassword(nextPassword());
        return super.getConnection(username, password);
    }
}
