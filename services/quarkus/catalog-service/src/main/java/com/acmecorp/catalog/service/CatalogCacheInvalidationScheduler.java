package com.acmecorp.catalog.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Status;
import jakarta.transaction.Synchronization;
import jakarta.transaction.TransactionSynchronizationRegistry;

import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class CatalogCacheInvalidationScheduler {

    private final TransactionSynchronizationRegistry transactionSynchronizationRegistry;
    private final CatalogProductCache productCache;

    public CatalogCacheInvalidationScheduler(TransactionSynchronizationRegistry transactionSynchronizationRegistry,
                                             CatalogProductCache productCache) {
        this.transactionSynchronizationRegistry = transactionSynchronizationRegistry;
        this.productCache = productCache;
    }

    public void invalidateProductAfterCommit(UUID productId) {
        registerAfterCommit(() -> productCache.invalidate(productId));
    }

    public void invalidateProductsAfterCommit(List<UUID> productIds) {
        registerAfterCommit(() -> productIds.forEach(productCache::invalidate));
    }

    private void registerAfterCommit(Runnable action) {
        int status = transactionSynchronizationRegistry.getTransactionStatus();
        if (status == Status.STATUS_NO_TRANSACTION) {
            action.run();
            return;
        }
        transactionSynchronizationRegistry.registerInterposedSynchronization(new Synchronization() {
            @Override
            public void beforeCompletion() {
            }

            @Override
            public void afterCompletion(int completionStatus) {
                if (completionStatus == Status.STATUS_COMMITTED) {
                    action.run();
                }
            }
        });
    }
}
