package com.acmecorp.catalog;

import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeUnit;

public class RedisTestResource implements QuarkusTestResourceLifecycleManager {

    private static final Duration REDIS_READY_TIMEOUT = Duration.ofSeconds(90);
    private String containerId;
    private int hostPort;

    @Override
    public Map<String, String> start() {
        hostPort = findFreePort();
        containerId = runCommand("docker", "run", "--rm", "-d", "-p", hostPort + ":6379", "redis:7.2-alpine").trim();
        waitForRedis();

        return Map.of(
                "quarkus.redis.hosts", "redis://127.0.0.1:%d".formatted(hostPort)
        );
    }

    @Override
    public void stop() {
        if (containerId != null && !containerId.isBlank()) {
            runCommand("docker", "rm", "-f", containerId);
        }
    }

    private void waitForRedis() {
        long deadline = System.nanoTime() + REDIS_READY_TIMEOUT.toNanos();
        long sleepMillis = 200L;
        String lastFailure = "Redis readiness probe did not run";
        while (System.nanoTime() < deadline) {
            try {
                if (!isContainerRunning()) {
                    lastFailure = "Container is not running";
                } else if (!isRedisPortOpen()) {
                    lastFailure = "Redis port %d is not accepting connections yet".formatted(hostPort);
                } else {
                    String result = runCommand("docker", "exec", containerId, "redis-cli", "ping").trim();
                    if ("PONG".equals(result)) {
                        return;
                    }
                    lastFailure = "Unexpected redis-cli ping response: " + result;
                }
            } catch (RuntimeException exception) {
                lastFailure = exception.getMessage();
            }

            try {
                Thread.sleep(sleepMillis);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("Interrupted while waiting for Redis to start", exception);
            }

            sleepMillis = Math.min(sleepMillis + 100L, 1_000L);
        }

        throw new RuntimeException("""
                Timed out waiting for Redis test container to become ready after %d seconds.
                Container state: %s
                Last readiness failure: %s
                Container logs:
                %s
                """.formatted(
                REDIS_READY_TIMEOUT.toSeconds(),
                describeContainerState(),
                lastFailure,
                safeContainerLogs()
        ));
    }

    private boolean isContainerRunning() {
        String result = runCommand("docker", "inspect", "-f", "{{.State.Status}}", containerId).trim();
        return "running".equalsIgnoreCase(result);
    }

    private boolean isRedisPortOpen() {
        try (Socket socket = new Socket("127.0.0.1", hostPort)) {
            return true;
        } catch (IOException exception) {
            return false;
        }
    }

    private String describeContainerState() {
        try {
            return runCommand("docker", "inspect", "-f", "status={{.State.Status}} exitCode={{.State.ExitCode}} startedAt={{.State.StartedAt}} finishedAt={{.State.FinishedAt}}", containerId).trim();
        } catch (RuntimeException exception) {
            return "unavailable: " + exception.getMessage();
        }
    }

    private String safeContainerLogs() {
        try {
            String logs = runCommand("docker", "logs", containerId);
            return logs.isBlank() ? "<no container logs>" : logs;
        } catch (RuntimeException exception) {
            return "unavailable: " + exception.getMessage();
        }
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
        Process process;
        try {
            process = new ProcessBuilder(command)
                    .redirectErrorStream(true)
                    .start();
            if (!process.waitFor(30L, TimeUnit.SECONDS)) {
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
