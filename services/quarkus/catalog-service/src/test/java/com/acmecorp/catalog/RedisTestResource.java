package com.acmecorp.catalog;

import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

import java.io.IOException;
import java.net.ServerSocket;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeUnit;

public class RedisTestResource implements QuarkusTestResourceLifecycleManager {

    private String containerId;
    private int hostPort;

    @Override
    public Map<String, String> start() {
        hostPort = findFreePort();
        runCommand(Duration.ofMinutes(5), "docker", "pull", "redis:7.2-alpine");
        containerId = runCommand(Duration.ofMinutes(2), "docker", "run", "--rm", "-d", "-p", hostPort + ":6379", "redis:7.2-alpine").trim();
        waitForRedis();

        return Map.of(
                "quarkus.redis.hosts", "redis://127.0.0.1:%d".formatted(hostPort)
        );
    }

    @Override
    public void stop() {
        if (containerId != null && !containerId.isBlank()) {
            runCommand(Duration.ofSeconds(30), "docker", "rm", "-f", containerId);
        }
    }

    private void waitForRedis() {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(30);
        while (System.nanoTime() < deadline) {
            try {
                String result = runCommand(Duration.ofSeconds(30), "docker", "exec", containerId, "redis-cli", "ping").trim();
                if ("PONG".equals(result)) {
                    return;
                }
            } catch (RuntimeException ignored) {
                // Redis is still starting.
            }

            try {
                Thread.sleep(250L);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("Interrupted while waiting for Redis to start", exception);
            }
        }

        throw new RuntimeException("Timed out waiting for Redis test container to become ready");
    }

    private static int findFreePort() {
        try (ServerSocket socket = new ServerSocket(0)) {
            socket.setReuseAddress(true);
            return socket.getLocalPort();
        } catch (IOException exception) {
            throw new RuntimeException("Unable to allocate a free TCP port for Redis tests", exception);
        }
    }

    private static String runCommand(String... command) {
        return runCommand(Duration.ofSeconds(30), command);
    }

    private static String runCommand(Duration timeout, String... command) {
        Process process;
        try {
            process = new ProcessBuilder(command)
                    .redirectErrorStream(true)
                    .start();
            if (!process.waitFor(timeout.toSeconds(), TimeUnit.SECONDS)) {
                process.destroyForcibly();
                throw new RuntimeException("Command timed out: " + String.join(" ", command));
            }
            String output = new String(process.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
            if (process.exitValue() != 0) {
                throw new RuntimeException("Command failed: " + String.join(" ", command) + "\n" + output);
            }
            return output;
        } catch (IOException exception) {
            throw new RuntimeException("Failed to run command: " + String.join(" ", command), exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Failed to run command: " + String.join(" ", command), exception);
        }
    }
}
