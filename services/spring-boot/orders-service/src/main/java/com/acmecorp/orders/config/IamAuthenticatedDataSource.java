package com.acmecorp.orders.config;

import org.postgresql.ds.PGSimpleDataSource;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.function.Supplier;

public class IamAuthenticatedDataSource extends PGSimpleDataSource {

    private final Supplier<String> passwordSupplier;

    public IamAuthenticatedDataSource(Supplier<String> passwordSupplier) {
        this.passwordSupplier = passwordSupplier;
    }

    @Override
    public Connection getConnection() throws SQLException {
        setPassword(passwordSupplier.get());
        return super.getConnection();
    }

    @Override
    public Connection getConnection(String username, String password) throws SQLException {
        setPassword(passwordSupplier.get());
        return super.getConnection(username, password);
    }
}
