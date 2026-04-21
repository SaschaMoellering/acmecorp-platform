package com.acmecorp.catalog;

import io.quarkus.test.junit.QuarkusTestProfile;

import java.util.Map;

public class RedisUnavailableProfile implements QuarkusTestProfile {

    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of(
                "quarkus.redis.hosts", "redis://127.0.0.1:1"
        );
    }
}
