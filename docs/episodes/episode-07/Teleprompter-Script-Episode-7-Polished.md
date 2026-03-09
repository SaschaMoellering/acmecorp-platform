# Episode 7 — JVM Performance Baselines: Java 11 → 17 → 21

## Opening – Why JVM versions matter

In Episode 6, we looked at three different approaches to optimizing JVM startup: AppCDS, native images, and CRaC. But there's a more fundamental question we haven't addressed yet: which JVM version should you be running?

This isn't just a dependency update. It's an architectural decision. Staying on older JVM versions silently costs performance, memory efficiency, and stability. In this episode, we're going to establish a baseline by comparing Java 11, Java 17, and Java 21 running the same application—the AcmeCorp orders-service.

We're not going to look at language features or API changes. We're going to measure what actually matters in production: startup time, memory footprint, throughput, and garbage collection behavior.

---

## The JVM release cadence – Understanding LTS versions

**[DIAGRAM: E07-D01-startup-comparison]**

Before we dive into benchmarks, let's understand the JVM release model. Since Java 9, Oracle and the OpenJDK community have released a new Java version every six months. But not all versions are equal.

Java 11, 17, and 21 are Long-Term Support (LTS) releases. These are the versions that get security updates and bug fixes for years. Java 11 was released in 2018, Java 17 in 2021, and Java 21 in 2023.

Most production systems run on LTS versions because they need stability and long-term support. But each LTS release includes years of performance improvements, garbage collector enhancements, and JVM optimizations from the non-LTS releases in between.

When you stay on Java 11, you're not just missing new language features—you're missing six years of JVM performance work.

---

## The test setup – Same application, different JVMs

Let me show you the test setup. We have three branches in the repository: java11, java17, and java21. Each branch runs the exact same orders-service code with the same dependencies, just compiled and run on different JVM versions.

```bash
git branch -a | grep java
```

We see three branches: java11, java17, and java21. Let me check out the Java 11 branch first.

```bash
git checkout java11
cat pom.xml | grep java.version
```

The Java version is set to 11. Now let me build and run the service.

```bash
docker build -t orders-service-java11 .
time docker run --rm orders-service-java11
```

The service starts. Let me note the startup time. Now let me do the same for Java 17.

```bash
git checkout java17
docker build -t orders-service-java17 .
time docker run --rm orders-service-java17
```

And finally Java 21.

```bash
git checkout java21
docker build -t orders-service-java21 .
time docker run --rm orders-service-java21
```

Already, we can see differences in startup time. But startup is just one metric. Let's look at the full picture.

---

## Startup time comparison – The first impression

**[DIAGRAM: E07-D01-startup-comparison]**

Startup time is the first thing users notice. In containerized environments with autoscaling, every second of startup time matters.

The current repository snapshot does not include validated median startup numbers for this episode yet, so we should not present fixed values here.

Here is the exact rerun workflow for startup measurements:

```bash
# 1) Ensure local tracking branches exist (one-time setup)
git branch java11 origin/java11
git branch java17 origin/java17
git branch java21 origin/java21

# 2) Run 5 cold starts per Java version
for branch in java11 java17 java21; do
  for run in 1 2 3 4 5; do
    ONLY_BRANCH="$branch" WARMUP=60 DURATION=120 CONCURRENCY=25 bash bench/run-matrix.sh
  done
done
```

Raw outputs are written to:
- `bench/results/<branch>/<timestamp>/summary.md`
- `bench/results/<branch>/<timestamp>/load.json`
- `bench/results/<branch>/<timestamp>/containers.json`
- `bench/results/<timestamp>/matrix-summary.md`

Once those five runs are complete for each branch, we report medians only.

---

## Memory footprint comparison – The hidden cost

**[DIAGRAM: E07-D02-memory-footprint-comparison]**

Startup time is visible, but memory footprint is often hidden until you hit resource limits. Let me run the services with memory tracking enabled.

```bash
docker stats orders-service-java11
docker stats orders-service-java17
docker stats orders-service-java21
```

Memory numbers in this script must come from the same benchmark rerun output set. Until those measured files are present, we keep this section qualitative only.

After rerunning, use `containers.json` from each run and report median memory snapshots per Java version.

---

## Garbage collection behavior – The throughput impact

Memory footprint is one thing, but how efficiently does the JVM manage that memory? Let me run a load test and watch the garbage collection metrics.

```bash
# Start the service with GC logging enabled
docker run -e JAVA_TOOL_OPTIONS="-Xlog:gc*:stdout" orders-service-java21
```

Now let me generate some load using k6.

```bash
k6 run --vus 50 --duration 60s load-test.js
```

While the load test runs, watch the GC logs. We only report GC pause and frequency numbers when we have saved logs for each Java version from the same benchmark session.

---

## Throughput comparison – Requests per second

Let me run a proper throughput benchmark. I'll use the same load test script but measure requests per second at different concurrency levels.

```bash
# Throughput and latency are already captured by bench/run-matrix.sh.
# Use load.json from each run and report medians:
# - requests_per_sec
# - p50 / p95 / p99 latency
```

We do not state fixed throughput deltas in this script until those medians are computed from measured `load.json` files.

---

## Virtual threads – The Java 21 advantage

Java 21 introduces virtual threads as a stable feature. This is a game-changer for I/O-bound applications like web services.

Let me show you the difference. First, let me check the thread count for the orders-service running on Java 11 with platform threads.

```bash
docker exec orders-service-java11 jcmd 1 Thread.print | grep "java.lang.Thread.State" | wc -l
```

Record the actual platform-thread count from this command in the run notes; do not assume a fixed value.

Now let me enable virtual threads in Java 21. I'll add this to application.yml:

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

Rebuild and run the service, then check the thread count again.

```bash
docker exec orders-service-java21 jcmd 1 Thread.print | grep "java.lang.Thread.State" | wc -l
```

Record the actual platform-thread count after enabling virtual threads; do not assume a fixed value.

This means we can handle more concurrent requests with less memory and less context switching overhead. For I/O-bound workloads, this is a massive improvement.

---

## Real-world impact – Cost and capacity

Let's translate these improvements into real-world impact. Assume you're running 100 containers of the orders-service in production.

Translate real-world impact only after medians are computed from measured startup, memory, and throughput outputs for Java 11, 17, and 21.

---

## The upgrade path – Is it worth it?

The performance improvements are clear, but is upgrading worth the effort? Let's be honest about the costs.

Upgrading from Java 11 to Java 17 is relatively straightforward. Java 17 is mostly backward compatible. You might need to update some dependencies, but most well-maintained libraries already support Java 17.

Upgrading from Java 17 to Java 21 is even easier. The main changes are new features, not breaking changes. If your code compiles on Java 17, it will almost certainly compile on Java 21.

The real cost is testing. You need to verify that your application behaves correctly on the new JVM. You need to test performance under load. You need to validate that third-party libraries work as expected.

When the rerun data is complete, we can present measured startup, memory, GC, and throughput deltas with confidence.

---

## When to upgrade – Timing and risk

Not every team can upgrade immediately. Legacy applications, vendor dependencies, and organizational constraints are real.

But here's the thing: the longer you wait, the harder it gets. Java 11 will reach end-of-life eventually. When that happens, you'll be forced to upgrade, and you'll have years of changes to deal with at once.

Incremental upgrades are less risky than big-bang migrations. If you're on Java 11, upgrade to Java 17 first. Test thoroughly, deploy to production, and stabilize. Then plan the upgrade to Java 21.

Each LTS release gives you three years before the next one. That's plenty of time to plan, test, and execute an upgrade.

---

## Closing – Performance is not free

JVM performance improvements don't happen automatically. You have to upgrade to get them.

Staying on Java 11 in 2024 is like running a 2018 car engine in a 2024 car. It works, but you're leaving performance on the table.

Java 21 includes major JVM improvements over Java 11, and this episode's benchmark workflow is designed to quantify that with reproducible measurements.

In the next episode, we'll look at another performance topic: profiling and optimization techniques using modern JVM tools. But we can only do that effectively if we're running on a modern JVM.

You can't optimize what you're not measuring. And you can't measure improvements if you're stuck on old infrastructure.

Upgrade your JVM. Measure the impact. Reap the benefits.
