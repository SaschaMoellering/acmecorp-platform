# Episode 10 — Understanding JVM Performance Signals

## Opening – Numbers without context are noise

Throughout this series we have been running services, measuring them, and making decisions based on what we observed. We looked at request latency, heap usage, garbage collection pause times, and startup duration. We used those signals to guide changes.

But there is a skill that sits underneath all of that, and it is easy to skip over. Before you can act on a performance signal, you have to understand what it is actually telling you. And more importantly, you have to understand what it is not telling you.

Performance problems are rarely caused by a single metric. They emerge from interactions. Startup behavior affects how a service looks under early load. Memory allocation patterns affect how often garbage collection runs. Garbage collection behavior affects tail latency. Tail latency affects how dependent services behave under backpressure. Pull on one thread and the whole fabric moves.

This episode is about performance literacy. Not benchmarking, not tooling, not statistical rigor. Those come later. This episode is about learning to look at a performance number and ask the right question instead of drawing the wrong conclusion. That skill is more valuable than any specific tool, because it applies everywhere, regardless of which JVM version you are running, which framework you are using, or which cloud you are deploying to.

---

## Startup time vs steady-state behavior – Two different systems

**[DIAGRAM: E10-D01-startup-vs-steady-state]**

```mermaid
flowchart LR
    subgraph Startup Phase
        S1[JVM init\nclass loading]
        S2[Framework bootstrap\nDI container, bean wiring]
        S3[Interpreter mode\nno JIT compilation yet]
        S4[Warmup\nJIT compiling hot paths]
    end

    subgraph Steady State
        SS1[JIT-compiled hot paths\noptimized native code]
        SS2[Stable heap\npredictable GC cadence]
        SS3[Consistent latency\nlow variance]
    end

    S1 --> S2 --> S3 --> S4 --> SS1
    SS1 --> SS2 --> SS3
```

The first concept to get right is the difference between startup time and steady-state behavior. These are not two points on the same curve. They are two fundamentally different operating modes of the JVM, and conflating them leads to bad conclusions.

During startup, the JVM is loading classes, initializing the framework, wiring the dependency injection container, and running in interpreted mode. The JIT compiler has not yet had enough information to compile the hot paths into optimized native code. Everything is slower than it will eventually be. Memory allocation is irregular. Latency is high and variable. If you measure performance during this phase and draw conclusions about steady-state behavior, you will be wrong.

Steady state is what happens after the JVM has warmed up. The JIT compiler has identified the hot paths and compiled them. The heap has settled into a predictable allocation and collection rhythm. Latency is lower and more consistent. This is the operating mode that matters for production workloads, because production services run for hours or days, not seconds.

The practical implication is that startup time and steady-state throughput are independent concerns. A service can start slowly and perform excellently under load. A service can start quickly and perform poorly under sustained traffic. Optimizing startup time does not improve steady-state performance. Optimizing steady-state performance does not reduce startup time. They require different techniques and different measurements.

Startup time is also not something you can read off a live Prometheus dashboard. It is captured separately, through benchmark scripts or container trace artifacts, because by the time the service is scraping metrics, the startup phase is already over. The live dashboard shows you steady-state behavior. Startup is a different measurement, taken in a different way. When you look at the Grafana dashboards for this platform, you are always looking at a service that has already warmed up. Keep that boundary in mind.

---

## Throughput vs latency vs tail latency – Three different questions

**[DIAGRAM: E10-D02-latency-distribution]**

```mermaid
flowchart TD
    subgraph Request Latency Distribution
        P50[p50 — median\n50% of requests faster than this]
        P95[p95 — 95th percentile\n95% of requests faster than this]
        P99[p99 — 99th percentile\n99% of requests faster than this]
        P999[p99.9 — tail\n999 in 1000 requests faster than this]
    end

    subgraph What They Tell You
        T50[Typical user experience]
        T95[Degraded but common experience]
        T99[Rare but real outliers]
        T999[Worst-case behavior\noften caused by GC pauses]
    end

    P50 --> T50
    P95 --> T95
    P99 --> T99
    P999 --> T999
```

Throughput, latency, and tail latency are three different questions about the same system. They are related, but they are not interchangeable, and optimizing for one can actively harm another.

Throughput is how many requests the system can handle per unit of time. It is a capacity question. A system with high throughput can process a large volume of work. But throughput says nothing about how long any individual request takes.

Latency is how long a single request takes from the caller's perspective. It is a responsiveness question. A system with low latency responds quickly to individual requests. But latency measured as an average hides the distribution. A system where ninety-nine requests complete in one millisecond and one request takes one second has an average latency of around eleven milliseconds. That average is not useful. The one-second request is the one that matters to the user who experienced it.

Tail latency is the behavior at the high percentiles. The p99 latency is the latency that ninety-nine percent of requests are faster than. The p99.9 latency is the latency that 999 out of 1000 requests are faster than. These numbers reveal the outliers, and outliers matter more than averages in distributed systems.

Here is why tail latency matters so much in practice. When a service makes multiple downstream calls to complete a request, the total latency is dominated by the slowest call. If each of five downstream services has a p99 latency of 100 milliseconds, the probability that at least one of them hits that p99 on any given request is much higher than one percent. The tail latencies compound. A system that looks fine in isolation can produce poor end-to-end latency when composed with other services.

In the JVM context, tail latency spikes are often caused by garbage collection pauses. A GC pause stops all application threads for a period of time. Every request that was in flight during that pause experiences the pause as added latency. When you see a latency distribution with a long right tail, GC behavior is one of the first things to investigate.

The dashboards for this platform show p95 latency as the primary signal. That is a useful window into degraded behavior, but it is not the full tail story. What is happening at p99 or beyond is not directly visible here. For that you need load test results or a more detailed histogram. The p95 line tells you something is happening. It does not tell you how bad the worst cases are. Keep that gap in mind when you are reading the charts.

The right question when looking at latency numbers is not what is the average. It is what does the distribution look like, and what is causing the tail.

---

## Memory footprint and allocation patterns – What the heap is telling you

**[DIAGRAM: E10-D03-memory-signal-overview]**

```mermaid
flowchart TD
    subgraph JVM Memory
        Heap[Heap\nYoung Gen + Old Gen]
        Native[Native Memory\nmetaspace, threads, JIT code cache]
        RSS[RSS — Resident Set Size\ntotal process memory from OS view]
    end

    subgraph GC Interaction
        Alloc[Allocation rate\nobjects created per second]
        Minor[Minor GC\nYoung Gen collection]
        Major[Major GC\nOld Gen collection — stop-the-world]
        Pause[GC Pause\nall threads stopped]
    end

    Heap -->|fills with allocations| Alloc
    Alloc -->|triggers| Minor
    Minor -->|survivors promoted| Major
    Major -->|causes| Pause
    Native --> RSS
    Heap --> RSS
```

Memory signals are among the most misread signals in JVM performance. The heap size reported by the JVM is not the same as the memory the process is using from the operating system's perspective. Understanding the difference matters when you are sizing containers, setting resource limits in Kubernetes, or comparing memory usage across JVM versions.

The heap is where Java objects live. It is divided into generations. The young generation is where new objects are allocated. Most objects die young, they are allocated, used briefly, and then become unreachable. The garbage collector reclaims them during a minor GC, which is fast and happens frequently. Objects that survive enough minor GC cycles are promoted to the old generation. The old generation is collected less frequently, but when it is collected, the pause is longer.

The allocation rate is how fast new objects are being created. A high allocation rate means the young generation fills up quickly, which means minor GC runs frequently. Frequent minor GC is not necessarily a problem, but it does consume CPU. If the allocation rate is high enough that objects are being promoted to the old generation faster than the old generation can be collected, heap pressure builds and eventually you get a long GC pause or an out-of-memory error.

Native memory is everything outside the heap. The metaspace holds class metadata. The JIT code cache holds compiled native code. Thread stacks consume native memory. The direct byte buffer pool, used by frameworks like Netty, lives in native memory. The RSS, resident set size, is the total memory the process is using from the operating system's perspective, and it includes both heap and native memory.

This distinction matters in Kubernetes. When you set a memory limit on a container, Kubernetes enforces it against the RSS, not the heap. If you set the JVM heap to 512 megabytes and the container memory limit to 512 megabytes, the container will be OOM-killed because the native memory overhead pushes the RSS above the limit. A common rule of thumb is to set the container memory limit to roughly 1.5 times the maximum heap size, but the right number depends on the workload and the JVM version.

The Grafana dashboards for this platform show heap metrics from Micrometer. That gives you a clear view of heap usage, GC behavior, and allocation pressure. What it does not show is the full container memory picture. The RSS is not surfaced here. It exists in the offline benchmark artifacts, where container memory is measured separately. So when you are reading the heap charts, remember that you are looking at one part of the memory story. The heap can look healthy while native memory overhead is pushing the container toward its limit. Those two views need to be read together, even if they come from different places.

When you look at the heap metrics, the questions to ask are: what is the allocation rate, how often is GC running, how long are the pauses, and is the heap growing over time or is it stable? A heap that grows steadily over hours is a memory leak. A heap that oscillates in a sawtooth pattern is normal GC behavior. A heap that is consistently near its maximum is a sizing problem.

---

## JVM version changes affect signals, not just speed

One of the most important things to understand when comparing performance across JVM versions is that newer JVM versions do not just make things faster. They change the signals themselves.

Garbage collectors have evolved significantly across JVM versions. The G1 collector, which became the default in JDK 9, behaves differently from the parallel collector that was default before it. ZGC and Shenandoah, which became production-ready in later JDK versions, are designed to keep GC pauses under a millisecond regardless of heap size. If you compare GC pause times between JDK 11 and JDK 21, you are not just seeing a performance improvement. You are seeing a different collector with a fundamentally different pause model.

JIT compilation has also improved across versions. JDK 21 includes improvements to the JIT compiler that reduce the time to reach peak performance after startup. This means the warmup phase is shorter, and the steady-state performance is reached sooner. Startup time comparisons between JDK versions reflect this, but because startup is measured offline rather than through the live dashboard, you need to look at the benchmark artifacts to see it. What the live dashboard shows you is the steady-state result of that faster warmup, not the warmup itself.

Memory footprint has changed too. JDK versions have introduced improvements to object layout, string compression, and class data sharing that reduce both heap usage and native memory overhead. A service that uses 400 megabytes of RSS on JDK 11 might use 320 megabytes on JDK 21 running the same workload. That difference shows up in the offline container memory measurements, not in the heap charts in Grafana. It changes how you size your containers and set your resource limits, but you have to look in the right place to see it.

The practical implication is that when you see a performance comparison between JVM versions, you need to understand what changed in the runtime, not just read the numbers. A 20% throughput improvement might come from a better JIT compiler, a more efficient GC, reduced memory pressure, or all three. Understanding which factor is driving the improvement tells you whether the improvement will hold under your specific workload, or whether it depends on characteristics that your workload does not have.

---

## Reading a real dashboard – What to look for and what to ignore

Let me walk through how to read a performance dashboard with these concepts in mind.

The first thing to establish is the time window. The live dashboard shows steady-state behavior. Startup is already over by the time metrics are being scraped. But if the service was restarted recently and the window includes the first few minutes of operation, the numbers may still reflect the tail end of warmup rather than true steady state. Narrow the window to a period of stable operation before drawing conclusions.

The second thing to look at is the latency signal. The dashboard shows p95, which tells you how the system behaves for the large majority of requests. A rising p95 is a meaningful signal. But p95 is not the full picture. It does not tell you what is happening at p99 or beyond, and those are the percentiles where GC pauses tend to show up most clearly. If you want to understand the tail, you need to look at the load test results alongside the dashboard, not just the dashboard alone.

The third thing to look at is the GC metrics. How often is GC running? How long are the pauses? Is the old generation growing over time or is it stable? A stable old generation with regular minor GC is healthy. An old generation that grows steadily until a major GC clears it is a sign of object promotion pressure. An old generation that never shrinks is a memory leak.

The fourth thing to look at is the allocation rate. A high allocation rate is not inherently a problem, but it is a signal. If the allocation rate is high and the GC pause times are also high, the two are likely related. If the allocation rate is high but GC pauses are short, the GC is keeping up. If the allocation rate drops suddenly, something changed in the workload, either traffic decreased or a code path that was allocating heavily is no longer being called.

The fifth thing to look at is the relationship between metrics. Latency spikes that align with GC pauses tell a different story than latency spikes that align with upstream dependency timeouts. Memory growth that correlates with request volume tells a different story than memory growth that continues after traffic stops. The signals are most useful when you look at them together, not in isolation. And some signals, like container memory or startup time, are not in this view at all. Knowing what is absent from the dashboard is just as important as knowing how to read what is there.

---

## What these signals allow you to conclude — and what they do not

This is the part that is most often skipped, and it is the most important. Every performance measurement has a scope, and conclusions drawn outside that scope are not valid.

A measurement taken on one JVM version does not tell you how the same code will behave on a different JVM version. The runtime is part of the system. Changing the runtime changes the behavior.

A measurement taken under one workload shape does not tell you how the system will behave under a different workload shape. A service that performs well under uniform low-concurrency traffic may behave very differently under bursty high-concurrency traffic. The GC behavior, the JIT compilation profile, and the connection pool behavior all depend on the workload.

A measurement taken in a container with specific resource limits does not tell you how the system will behave with different limits. The JVM adapts its behavior to the available memory and CPU. A service running with 512 megabytes of heap will have different GC behavior than the same service running with 2 gigabytes of heap.

A single measurement does not tell you about variance. A service that has a p95 latency of 5 milliseconds might have a p99.9 latency of 500 milliseconds. The p95 is not the full story. The shape of the distribution beyond what the dashboard shows is the story, and for that you need the load test data.

What performance signals do allow you to conclude is whether the system is behaving consistently, whether there are outliers that need investigation, whether resource usage is growing in a way that suggests a leak, and whether a change you made improved or degraded the metrics you care about. They are diagnostic tools, not verdicts. And a correlation between two signals is a reason to investigate, not a confirmed cause.

---

## Closing – Literacy before optimization

We have covered a lot of ground in this episode without writing a single benchmark or running a single load test. That was deliberate.

Performance literacy is the prerequisite for performance work. If you do not understand what startup time and steady-state behavior mean, you will optimize the wrong thing. If you do not understand the difference between p95 and tail latency, you will miss the problems that matter most to users. If you do not understand how GC behavior affects the signals you are reading, you will misdiagnose the cause of latency spikes. If you do not understand how JVM version changes affect the signals themselves, you will draw wrong conclusions from comparisons.

The signals we looked at in this episode, startup phase versus steady state, latency percentiles, allocation rate, GC pause behavior, heap stability, and the gap between heap and total container memory, are the vocabulary of JVM performance. They appear in every dashboard, every profiler output, and every benchmark result. Understanding what they mean, and understanding what each view does and does not show you, is what allows you to ask the right question when something looks wrong.

In the next episode, we will build on this foundation. We will look at how to construct measurements that are actually valid, how to control for the variables that affect JVM performance, and how to draw conclusions that hold up under scrutiny. But that work only makes sense if you already understand what you are measuring and why it matters.

Understand the signals first. Then measure.
