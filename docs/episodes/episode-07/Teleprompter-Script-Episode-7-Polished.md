# Episode 7 — Platform Branch Benchmarks: Java 11 → 17 → 21 → 25

## Opening – Why platform generations matter

In Episode 6, we looked at three different approaches to optimizing JVM startup: AppCDS, native images, and CRaC. But there's a more fundamental question we haven't addressed yet: what does it actually cost—or gain—to move your platform forward across Java generations?

This isn't just a JVM swap. Each branch in this repository represents a maintained platform generation: a different Java version, yes, but also the framework versions, packaging choices, and configuration that go with it. These are the kinds of changes real teams ship when they upgrade. In this episode, we benchmark four of those branches—Java 11, Java 17, Java 21, and Java 25—running the AcmeCorp orders-service.

We're not going to look at language features or API changes. We're going to measure what actually matters in production: startup time, memory footprint, throughput, and garbage collection behavior.

---

## The JVM release cadence – Understanding LTS versions

Before we dive into the benchmark results, let's ground this in the JVM release model. Since Java 9, Oracle and the OpenJDK community have released a new Java version every six months. But not all versions play the same role in production.

Java 11, 17, and 21 are Long-Term Support (LTS) releases. These are the versions that get security updates and bug fixes for years. Java 11 was released in 2018, Java 17 in 2021, and Java 21 in 2023.

Most production systems run on LTS versions because they need stability and long-term support. And each LTS release carries years of JVM work forward: garbage collector changes, runtime tuning, and startup improvements from the non-LTS releases in between.

So when you stay on Java 11, you're not just missing language features. You're also opting out of several generations of platform and JVM evolution. This benchmark does not isolate JVM-only effects, but it does show what those maintained branch generations look like in practice.

---

## The test setup – Repository-maintained platform branches

Let me show you the test setup. We have four benchmark branches in the repository: java11, java17, java21, and java25. Each branch is a repository-maintained platform branch aligned with a different Java generation—meaning the JVM, framework versions, packaging, and configuration all reflect what that generation looks like in practice.

```bash
git branch -a | grep java
```

We see four benchmark branches: java11, java17, java21, and java25. Let me check out the Java 11 branch first.

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

Then Java 21.

```bash
git checkout java21
docker build -t orders-service-java21 .
time docker run --rm orders-service-java21
```

And then Java 25.

```bash
git checkout java25
docker build -t orders-service-java25 .
time docker run --rm orders-service-java25
```

Already, we can see differences in startup time. But startup is just one metric. Let's look at the full picture.

---

## Startup time comparison – The first impression

Startup time is the first thing users notice. In containerized environments with autoscaling, every second of startup time matters.

**[DIAGRAM: E07-D01-startup-comparison]**

Let's look at the startup numbers first. This chart compares the maintained platform branches side by side. It shows two startup metrics for each branch. Here is the exact rerun workflow for those measurements:

```bash
# 1) Ensure local tracking branches exist (one-time setup)
for branch in java11 java17 java21 java25; do
  git show-ref --verify --quiet "refs/heads/$branch" || git branch --track "$branch" "origin/$branch"
done

# 2) Run the canonical refresh workflow
RUNS_PER_BRANCH=5 WARMUP=60 DURATION=120 CONCURRENCY=25 DO_FETCH=0 BRANCHES="java11 java17 java21 java25" bash bench/run-episode07-refresh.sh
```

Raw outputs are written to:
- `bench/results/<branch>/<timestamp>/summary.md`
- `bench/results/<branch>/<timestamp>/orders-startup.json`
- `bench/results/<branch>/<timestamp>/load.json`
- `bench/results/<branch>/<timestamp>/containers.json`
- `bench/results/<timestamp>/matrix-summary.md`

Once those 5 runs are complete, we report medians only.

Two startup metrics are reported here, and the distinction matters. External readiness is measured at the gateway. It reflects the full stack coming up: infrastructure, networking, the works. The orders-service main-to-ready time is measured inside the application itself, from `main()` to `ApplicationReadyEvent`. That is the number that tells you how fast the application bootstraps, independent of everything around it. Main-to-ready is the primary startup metric we'll focus on.

Median results from the latest rerun set (RUNS_PER_BRANCH=5):
- Java 11: readiness 10.46s, orders-service main-to-ready 15759 ms, orders memory 1060.9 MiB, throughput 7281.6 req/s
- Java 17: readiness 10.99s, orders-service main-to-ready 19154 ms, orders memory 578.2 MiB, throughput 6995.6 req/s
- Java 21: readiness 9.31s, orders-service main-to-ready 17669 ms, orders memory 611.5 MiB, throughput 6701.8 req/s
- Java 25: readiness 11.06s, orders-service main-to-ready 15483 ms, orders memory 667.2 MiB, throughput 6193.0 req/s

Java 21 wins on full-stack readiness at 9.31 seconds. Java 25 wins on internal bootstrap with the fastest main-to-ready at 15483 ms. Already, the story is not a straight line from older to newer. Now let's add memory footprint to the picture.

---

## Memory footprint comparison – The hidden cost

Startup time is visible, but memory footprint is often hidden until you hit resource limits. Let me run the services with memory tracking enabled.

**[DIAGRAM: E07-D02-memory-footprint-comparison]**

```bash
docker stats orders-service-java11
docker stats orders-service-java17
docker stats orders-service-java21
docker stats orders-service-java25
```

This chart keeps the same maintained platform branches and the same five-run median methodology. These memory numbers are median orders-service container snapshots taken after readiness. They are supporting evidence, not a perfect model of steady-state behavior.

Java 17 lands at 578.2 MiB. Java 11 is at 1060.9 MiB, nearly double. That gap matters at scale. But memory is only one axis, and we have already seen that Java 11 leads on throughput. That tension is exactly what this episode is about.

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

Throughput here is a supporting metric, not the headline. It is measured through the full gateway path, so it reflects the behavior of each maintained platform branch, not just the JVM in isolation. At this point, the pattern becomes clear. Different branches lead different metrics.

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

In the right kind of I/O-bound workload, that can reduce platform-thread pressure and context switching overhead. But, as with the rest of this episode, we only claim what we actually measure.

---

## Real-world impact – Cost and capacity

Let's translate these numbers into real-world impact. Assume you're running 100 containers of the orders-service in production.

Java 17's memory footprint of 578.2 MiB versus Java 11's 1060.9 MiB is a meaningful difference at scale—that's nearly half the memory per container. But Java 11 still delivers the highest throughput at 7281.6 req/s. Depending on whether your bottleneck is memory or request capacity, those two facts point in different directions. That's exactly why you measure your own platform instead of assuming a universal upgrade story.

---

## The upgrade path – Understanding the tradeoffs

**[DIAGRAM: E07-D03-platform-tradeoffs]**

This chart makes the tradeoff structure explicit. Each branch leads a different metric. There is no single winner across all four dimensions. The results show real tradeoffs, not a clean upgrade story. So is upgrading worth the effort? Let's be honest about the costs.

Upgrading from Java 11 to Java 17 is relatively straightforward. Java 17 is mostly backward compatible. You might need to update some dependencies, but most well-maintained libraries already support Java 17.

Upgrading from Java 17 to Java 21 is even easier. The main changes are new features, not breaking changes. If your code compiles on Java 17, it will almost certainly compile on Java 21.

The real cost is testing. You need to verify that your application behaves correctly on the new JVM. You need to test performance under load. You need to validate that third-party libraries work as expected.

With the rerun data in place, we can now talk about measured startup, memory, and throughput tradeoffs with confidence. The last chart brings those tradeoffs together in one view.

---

## When to upgrade – Timing and risk

Not every team can upgrade immediately. Legacy applications, vendor dependencies, and organizational constraints are real.

But here's the thing: the longer you wait, the harder it gets. Java 11 will reach end-of-life eventually. When that happens, you'll be forced to upgrade, and you'll have years of changes to deal with at once.

Incremental upgrades are less risky than big-bang migrations. If you're on Java 11, upgrade to Java 17 first. Test thoroughly, deploy to production, and stabilize. Then plan the upgrade to Java 21.

Each LTS release gives you three years before the next one. That's plenty of time to plan, test, and execute an upgrade.

---

## Closing – The lesson is tradeoffs, not a winner

**[DIAGRAM: E07-D04-master-benchmark]**

This final chart summarizes the benchmark tradeoffs. It puts all four maintained platform branches on the same canvas. Startup, memory efficiency, throughput, internal bootstrap: each axis is normalized from the measured medians. Take a moment to look at the shape of each branch. No single branch dominates every axis.

Java 21 leads on full-stack readiness. Java 25 leads on internal bootstrap. Java 17 leads on memory efficiency. Java 11 still leads on throughput.

The lesson from this benchmark is not that newer Java always wins. This benchmark shows tradeoffs across platform generations. Real platform upgrades shift startup, memory, and throughput in different ways, and which dimension matters most depends on what your system needs.

That's why serious teams measure their own platform behavior instead of assuming a universal upgrade story.

In the next episode, we'll look at profiling and optimization techniques using modern JVM tools—because understanding your platform's actual behavior is where real performance work begins.
