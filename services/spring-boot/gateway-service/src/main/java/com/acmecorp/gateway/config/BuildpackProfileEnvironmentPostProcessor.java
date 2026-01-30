package com.acmecorp.gateway.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.Profiles;

public class BuildpackProfileEnvironmentPostProcessor implements EnvironmentPostProcessor, Ordered {

    private static final String BUILDPACK_PROFILE = "buildpack";
    private static final String BP_PROFILE_ENV = "BP_SPRING_PROFILES";
    private static final String BPL_PROFILE_ENV = "BPL_SPRING_PROFILES";
    private static final String BUILDPACK_MARKER = "CNB_STACK_ID";

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        if (environment.acceptsProfiles(Profiles.of(BUILDPACK_PROFILE))) {
            return;
        }

        String configured = firstNonEmpty(
                environment.getProperty(BPL_PROFILE_ENV),
                environment.getProperty(BP_PROFILE_ENV),
                buildpackMarkerProfile(environment));
        if (configured == null) {
            return;
        }

        if (containsProfile(configured, BUILDPACK_PROFILE)) {
            environment.addActiveProfile(BUILDPACK_PROFILE);
        }
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE + 10;
    }

    private static String firstNonEmpty(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }

    private static String buildpackMarkerProfile(ConfigurableEnvironment environment) {
        String marker = environment.getProperty(BUILDPACK_MARKER);
        if (marker == null || marker.isBlank()) {
            return null;
        }
        return BUILDPACK_PROFILE;
    }

    private static boolean containsProfile(String value, String profile) {
        for (String candidate : value.split("[,\\s]+")) {
            if (profile.equals(candidate.trim())) {
                return true;
            }
        }
        return false;
    }
}
