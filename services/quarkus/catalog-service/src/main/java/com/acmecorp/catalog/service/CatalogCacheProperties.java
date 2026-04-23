package com.acmecorp.catalog.service;

import io.smallrye.config.ConfigMapping;

import java.time.Duration;

@ConfigMapping(prefix = "catalog.cache")
public interface CatalogCacheProperties {

    Duration productTtl();
}
