package com.acmecorp.orders.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
@Profile("buildpack")
public class BuildpackProfileGuard implements ApplicationRunner {

    private static final String BUILDPACK_MARKER = "CNB_STACK_ID";

    private final Environment environment;

    public BuildpackProfileGuard(Environment environment) {
        this.environment = environment;
    }

    @Override
    public void run(ApplicationArguments args) {
        String marker = environment.getProperty(BUILDPACK_MARKER);
        if (marker == null || marker.isBlank()) {
            throw new IllegalStateException(
                    "The 'buildpack' profile is only supported during buildpack training runs. "
                            + "Unset the profile or set " + BUILDPACK_MARKER + " when running in buildpacks.");
        }
    }
}
