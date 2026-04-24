package com.acmecorp.catalog;

import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.OutputStream;
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
                if (hostPingRedis()) {
                    return;
                }
                lastFailure = "Unexpected Redis PING response from localhost:%d".formatted(hostPort);
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
                Last readiness failure: %s
                Container logs:
                %s
                """.formatted(
                REDIS_READY_TIMEOUT.toSeconds(),
                lastFailure,
                safeContainerLogs()
        ));
    }

    private boolean hostPingRedis() {
        try (Socket socket = new Socket("127.0.0.1", hostPort);
             OutputStream outputStream = socket.getOutputStream();
             BufferedInputStream inputStream = new BufferedInputStream(socket.getInputStream())) {
            socket.setSoTimeout(1_000);
            outputStream.write("*1\r\n$4\r\nPING\r\n".getBytes(java.nio.charset.StandardCharsets.UTF_8));
            outputStream.flush();
            String response = readLine(inputStream);
            return "+PONG".equals(response);
        } catch (IOException exception) {
            throw new RuntimeException("Redis did not respond to host-side PING on localhost:%d".formatted(hostPort), exception);
        }
    }

    private static String readLine(BufferedInputStream inputStream) throws IOException {
        StringBuilder builder = new StringBuilder();
        int current;
        while ((current = inputStream.read()) != -1) {
            if (current == '\r') {
                int next = inputStream.read();
                if (next == '\n') {
                    return builder.toString();
                }
                builder.append((char) current);
                if (next != -1) {
                    builder.append((char) next);
                }
            } else {
                builder.append((char) current);
            }
        }
        return builder.toString();
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
