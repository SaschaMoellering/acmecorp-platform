# Episode 11 — Cutting Edge JVMs: Java 21 vs Java 25

## Opening – Upgrades are decisions, not lottery tickets

In the previous episode, we built the vocabulary for reading JVM performance signals. We talked about what startup time, latency percentiles, heap behavior, and GC pauses actually mean, and what each of those signals does and does not tell you. That vocabulary matters now, because this episode is about applying it to a real decision.

Java 25 is a new major JVM release and a new LTS baseline. The release notes are long. The JEP list is impressive and blog posts are enthusiastic - for good reasons. 

A JVM upgrade is not a performance lottery ticket. You do not pull the lever and hope for a better number. It is a risk-managed decision, and like any risk-managed decision, it requires evidence. What changed? What does that change mean for your specific workload? What could go wrong?

This episode is about how to answer those questions for the AcmeCorp platform, using the benchmark infrastructure we have built and the signals we learned to read in the previous episode. We are going to look at what changed between Java 21 and Java 25, run the comparison, interpret the results honestly, and apply a structured go/no-go check before making a recommendation.

The goal is not to tell you that Java 25 is universally better or worse. The goal is to show you how to find out for yourself, on your own workload, with your own evidence.

---

## What changed between Java 21 and Java 25 – The change surface

**[DIAGRAM: E11-D01-java21-vs-java25-change-surface]**

```mermaid
flowchart TD
    subgraph Java 25 Change Surface
        GC[GC behavior\nGenerational ZGC default predates JDK 25\nG1 and ZGC continue to evolve]
        JIT[JIT compiler\npotentially faster warmup\nreduced code cache pressure]
        MEM[Memory footprint\nplausible RSS reduction\ncauses not fully isolated]
        LANG[Language features\nvirtual threads — stable since Java 21\nstructured concurrency — still preview in Java 25]
        COMPAT[Compatibility surface\ndeprecated APIs removed\nreflection restrictions tightened]
    end

    subgraph Impact on AcmeCorp
        LAT[Latency — GC pause behavior]
        START[Startup — warmup characteristics]
        RSS[Container memory — footprint signal]
        RISK[Compatibility risk — framework and library surface]
    end

    GC --> LAT
    JIT --> START
    MEM --> RSS
    COMPAT --> RISK
    LANG --> RISK
```

Before running a single benchmark, it is worth understanding what the change surface actually looks like. Not every change in a JVM release affects every workload. Some changes are relevant to your platform. Some are not. Knowing which is which tells you where to look in the benchmark results and what to be cautious about.

The GC story between Java 21 and Java 25 is more nuanced than a single headline change. Generational ZGC is not a Java 25 introduction. It became the default ZGC mode in an earlier release. What continues to evolve across JDK versions is the tuning and behavior of both G1 and ZGC under different workload shapes. If you are running with ZGC enabled, generational mode is already active on modern JDKs. The question for the benchmark is whether the GC behavior on Java 25 is measurably different from Java 21 under the same load, not whether a specific named feature has arrived.

The JIT compiler changes are harder to attribute precisely. Java 25 may show shorter startup times or faster warmup in the benchmarks, and that is worth measuring. But the cause is not always straightforward to isolate. JIT improvements, class loading changes, and framework initialization all interact. When the startup benchmark shows a difference, treat it as a signal worth noting rather than a confirmed causal statement about the JIT.

The memory footprint picture is similar. RSS differences between Java 21 and Java 25 are plausible and worth measuring in the offline container memory benchmarks. Object layout and heap representation have continued to improve across JDK versions. But the specific cause of any RSS difference you observe in the benchmark is not something the harness can prove. It is a directional signal, not a diagnosis.

On the language side, virtual threads are not a Java 25 feature. They became stable in Java 21. If the platform has not yet adopted them, that is a separate migration decision, not something Java 25 introduces. Structured concurrency is still in preview in Java 25. It is not a stable API, and it should not be treated as a production-ready feature for this platform.

The compatibility surface is where the risk lives. Java 25 continues the trend of tightening access to internal APIs, removing deprecated methods, and restricting reflection in ways that affect frameworks. The platform runs Spring Boot 4 and a compatible version of Quarkus for Java 25. 

---

## The version matrix setup – How the comparison is structured

Let me show you how the benchmark comparison is structured. The benchmark path in this repository is local, running through a Compose-based harness rather than against the deployed AWS environment. The entry point is `bench/run-matrix.sh`, which drives the comparison across the java21 and java25 matrix entries.

It is worth being precise about what the harness controls and what it does not. The matrix compares branches, which means there can be configuration drift between the two versions beyond just the JDK. The harness does not guarantee that the only variable is the JVM. That is the ideal, and it is worth aiming for, but it is not something the current setup can fully enforce. When you read the results, keep that in mind. A difference in the output could reflect a JVM change, a configuration difference, or both.

The load generation in the harness uses wrk or hey, not k6. k6 is part of the live observability stack for the running platform. The benchmark harness is a separate tool with a different purpose. Startup is measured offline by timing the container from cold start to first successful health check. Throughput and latency are measured offline by the load generator against the running container. Container memory is captured from docker stats after the service has been running under load. None of these measurements come from Prometheus or Grafana. They are all offline artifacts produced by the harness.

The comparison was executed with 5 runs per branch, a 120 second warmup, a 300 second measurement duration, and a concurrency of 25. That configuration produces a statistically meaningful result. Five runs with a long measurement window give us enough data to assess variance, and the variance in this case was low. The results were consistent across runs.

One additional constraint worth naming is that this is a branch comparison, not a pure JVM comparison. The Java 21 branch and the Java 25 branch do not differ only by the JDK. The Java 25 branch also carries newer framework versions and runtime assumptions. In this repository, the comparison is best described as a platform branch benchmark: Java 21 with its platform stack versus Java 25 with its platform stack.

That distinction is not a weakness as long as we name it clearly. In production, teams rarely upgrade only the JVM in total isolation. Runtime upgrades often arrive together with framework, dependency, and build changes. But it means we must not claim that every measured difference is caused by the JVM itself.

---

## Benchmark comparison – Reading the results

Let me walk through what the benchmark output looks like and how to read it.

The comparison was executed with 5 runs per branch, a 120 second warmup, a 300 second measurement duration, and a concurrency of 25. The results were consistent across all five runs with low variance. This is not noise. It is a systematic effect.

The final benchmark result after the investigation and optimization looked like this.

Java 21 reached a median throughput of approximately 6680 requests per second, with p95 at approximately 5.7 milliseconds and p99 at approximately 6.6 milliseconds.

Java 25 reached a median throughput of approximately 5480 requests per second, with p95 at approximately 7.2 milliseconds and p99 at approximately 8.4 milliseconds.

That means Java 25 was slower in this benchmark. Throughput was roughly 18 percent lower. p95 latency was roughly 26 percent higher. p99 latency was roughly 27 percent higher. Tail latency increased by approximately 20 to 30 percent across the distribution.

That is not a disaster, but it is also not a win. And this distinction matters. A JVM upgrade does not have to improve every number to be worth considering. But if the performance numbers regress consistently and with low variance across five runs, the decision needs a reason beyond enthusiasm.

The memory picture was mixed. Most services stayed in a similar range, but the orders service remained noticeably larger on Java 25. In the measured run, orders-service used roughly 543.8 MiB on Java 21 and 674.4 MiB on Java 25. That is a signal we should not ignore. It does not prove a memory leak, but it tells us that the Java 25 branch has a larger runtime footprint for the service that sits on the benchmark hot path.

One important lesson from this benchmark is that the first result was misleading until we investigated it. Earlier runs showed Java 25 much further behind, in the range of roughly forty to fifty percent lower throughput. At that point, the correct reaction was not to blame Java 25. The correct reaction was to isolate the hot path.

The endpoint under load was `GET /api/gateway/orders`. We compared the gateway path against the direct orders-service path. The direct orders-service endpoint was already much slower on Java 25, which told us the gateway was not the primary cause. We then checked payload size. The response was tiny and effectively identical between the branches, so the regression was not caused by sending more data.

The next check was the status endpoints. Both Java 21 and Java 25 handled the simple status endpoints at very high throughput. That ruled out a general HTTP server or Tomcat baseline problem. The slowdown was specific to the orders list path.

The diagnostic endpoints then isolated the cause further. The current path used a Spring Data JPA Specification, even for the unfiltered list case. On Java 25, with Spring Boot 4, Spring Data JPA 4, and Hibernate 7, that Specification and Criteria path had a measurable fixed per-request cost. When we bypassed the Specification path for unfiltered requests and used a simpler repository query, direct orders throughput improved significantly.

That optimization did not make Java 25 faster than Java 21. But it reduced the gap from a large regression to a more understandable platform difference. This is the point of benchmarking. The number is not the answer. The number is the beginning of the investigation.

---

## Risk vs reward – The decision matrix

**[DIAGRAM: E11-D02-risk-reward-decision-matrix]**

```mermaid
flowchart TD
    subgraph Reward Axis
        R1[Latency — GC pause behavior\nvisible in offline benchmark]
        R2[Startup — warmup characteristics\nnot captured in final run]
        R3[Memory — RSS signal\nmixed container measurements]
        R4[Long-term support\nJava 25 is an LTS release]
    end

    subgraph Risk Axis
        X1[Compatibility risk\nframework versions not fully verified]
        X2[Operational risk\nunknown failure modes in production]
        X3[Rollback cost\ncomplexity of reverting a JVM upgrade]
        X4[Timing risk\nupgrading during a high-traffic period]
    end

    subgraph Decision
        GO[Go — reward exceeds risk\nwith mitigations in place]
        NOGO[No-go — risk not justified\nby observed reward]
        DEFER[Defer — reward is real\nbut timing is wrong]
    end

    R1 & R2 & R3 & R4 --> GO
    X1 & X2 & X3 & X4 --> NOGO
    GO & NOGO --> DEFER
```

The benchmark results give you the reward side of the decision. Now let me talk about the risk side, because that is where most upgrade decisions go wrong.

The first risk is compatibility. Java 25 tightens access to internal APIs and removes deprecated methods that were still present in Java 21. If any of the platform's dependencies use those APIs, the service will fail at startup or at runtime in ways that may not be immediately obvious. The Java 21 branch runs Spring Boot 3.3.4 and Quarkus 3.15.0. The Java 25 branch uses newer framework baselines, including Spring Boot 4 and a compatible Quarkus version. Whether those specific versions are fully compatible with Java 25 needs to be verified explicitly. Do not assume compatibility based on the framework name alone. Check the framework's own compatibility matrix for the exact version in use.

The practical way to do this is to run the full test suite against Java 25 before running any benchmarks. If the tests pass, the compatibility surface is likely clean for the paths the tests exercise. If they fail, the failure tells you exactly where the incompatibility is. Fix it or wait for the dependency to release a compatible version. Do not benchmark a version that does not pass the tests.

The second risk is operational unknowns. A JVM version that performs well in a benchmark environment may behave differently under production traffic patterns, with production data volumes, and with production dependency latencies. The benchmark is a controlled approximation. Production is the real thing. The gap between them is where surprises live.

The third risk is rollback cost. Rolling back a JVM upgrade is not as simple as rolling back an application deployment. The JVM is baked into the container image. Rolling back means rebuilding and redeploying the previous image. In a GitOps model this is straightforward, you revert the image tag change and let the reconciler apply it. But it is still a deployment event, and deployment events carry their own risk. The rollback path needs to be tested before the upgrade is applied, not after something goes wrong.

The fourth risk is timing. Upgrading a JVM during a high-traffic period, before a major release, or when the team is already managing another change is a bad idea regardless of how good the benchmark results look. The upgrade should happen during a period of low operational pressure, with the team available to respond if something unexpected happens.

---

## Operational stability checks – The go/no-go checklist

**[DIAGRAM: E11-D03-operational-stability-checks]**

```mermaid
flowchart TD
    C1{Tests pass\non Java 25?}
    C2{No crash loops\nin staging?}
    C3{GC behavior\nstable under load?}
    C4{p95 latency\nnot worse than Java 21?}
    C5{Container RSS\nwithin limits?}
    C6{Rollback path\ntested?}

    C1 -->|No| NOGO[No-go]
    C1 -->|Yes| C2
    C2 -->|No| NOGO
    C2 -->|Yes| C3
    C3 -->|No| NOGO
    C3 -->|Yes| C4
    C4 -->|No| NOGO
    C4 -->|Yes| C5
    C5 -->|No| NOGO
    C5 -->|Yes| C6
    C6 -->|No| NOGO
    C6 -->|Yes| GO[Go]
```

Let me walk through the checklist against the AcmeCorp platform. Not to declare a verdict, but to show what each check actually requires and where the current state of the repository leaves open questions.

The first check is whether the tests pass on Java 25. This is the gate that everything else depends on. Run the full test suite, including integration tests that exercise the database connection, the message broker, and the observability wiring. A unit test suite that passes is not sufficient. The compatibility risk lives in the integration surface.

The second check is whether the service runs without crash loops under load. Start the service on Java 25, send it representative traffic, and watch the restart count. A service that crashes and restarts under load is not ready for production regardless of what the benchmarks show. Crash loops under load often indicate memory pressure that the benchmark environment did not reproduce, or a runtime error triggered by a specific code path that the load generator did not exercise. This check requires a deliberate staging run, not just a benchmark pass.

The third check is whether GC behavior is stable under load. Look at the GC pause frequency and duration during the benchmark run. Erratic pause behavior or unexpected full GC events are a signal that something is wrong with the configuration or that the workload is triggering an edge case. What you are looking for is stability and consistency, not necessarily a specific improvement over Java 21.

The fourth check is whether p95 latency is not worse than the Java 21 baseline. This is a floor, not a ceiling. The goal is not to require an improvement. The goal is to ensure there is no regression. A JVM upgrade that makes latency worse is not acceptable even if the benchmark showed a throughput improvement. Throughput and latency are different questions, and a latency regression affects users directly.

The fifth check is whether the container RSS is within the configured memory limits. If the Java 25 RSS is higher than expected, the container memory limit may need to be adjusted before deploying to production. An OOM kill in production because the memory limit was sized for the Java 21 footprint is an avoidable failure.

The sixth check is whether the rollback path has been tested. Before applying the upgrade to production, verify that you can revert to the Java 21 image and that the revert deploys cleanly. In a GitOps model this means reverting the image tag in the deployment manifest, opening a pull request, merging it, and confirming that the reconciler applies the previous image without errors. Do this in staging before doing it in production.

---

## Applying the checklist to the platform

Let me be direct about where the platform stands against this checklist right now.

The benchmark gives us useful evidence, but it does not produce an automatic go decision.

The Java 25 branch now starts, runs the benchmark path, and no longer shows the severe performance regression we saw initially. That is important. The initial result looked much worse. After isolating the orders-service hot path, we found that the unfiltered list endpoint was paying the cost of the Specification and Criteria path unnecessarily. Bypassing that path for unfiltered requests improved direct orders throughput and reduced the platform benchmark gap substantially.

But the final result is still not a performance win for Java 25. Across five runs with low variance, Java 25 delivered a median of approximately 5480 requests per second versus approximately 6680 on Java 21. That is a systematic throughput difference of roughly 18 percent, not measurement noise. p95 latency moved from approximately 5.7 milliseconds to approximately 7.2 milliseconds, and p99 moved from approximately 6.6 milliseconds to approximately 8.4 milliseconds. These numbers were consistent across all five runs. This is a real effect, and it needs to be understood before any production rollout decision is made.

The crash-loop check has improved. During the investigation, the Java 25 branch exposed real startup issues: missing framework wiring, Flyway startup behavior, and a notification-service Jackson runtime problem. These are exactly the kinds of compatibility issues a JVM and framework upgrade can surface. Fixing them is part of the upgrade process, not an optional cleanup step.

The memory check remains open. The orders-service RSS is still higher on Java 25. It is within the local container run, but it would need to be checked against the actual Kubernetes memory limits before any production rollout.

The rollback check is still not addressed by the benchmark harness. It requires a deliberate staging exercise. The benchmark can tell us whether the application is worth further validation. It cannot prove that rollback works.

The honest conclusion is this: Java 25 is now viable enough to continue evaluating, but the benchmark evidence shows a systematic performance regression that must be explained before a go decision can be made. If the reason to move is long-term support, framework alignment, and staying current, the branch is a reasonable candidate for continued hardening. If the reason to move is immediate performance improvement, the current evidence does not support that claim.

That is not a failure of the process. That is the process working correctly. We found a regression, isolated it, fixed the largest avoidable cause, and ended with a more accurate and reproducible result.

## What is intentionally deferred

This episode has not gone deep into individual JEPs. The Java Enhancement Proposal list for Java 25 is long, and most of the entries are not directly relevant to a platform like AcmeCorp. Virtual threads became stable in Java 21, and the AcmeCorp services use traditional thread-per-request models. The migration to virtual threads is a separate decision with its own tradeoffs, and it is not something Java 25 introduces. Structured concurrency remains in preview in Java 25 and is not a stable API for production adoption.

The point is not to evaluate every feature in the release. The point is to evaluate the features that affect your workload, measure the ones that can be measured, and make a decision based on evidence rather than release notes.

---

## Closing – Evidence over enthusiasm

Every major JVM release comes with a wave of enthusiasm. Benchmark numbers from the OpenJDK team, blog posts from framework authors, conference talks about new features. All of that is useful context, but none of it is a substitute for running the comparison yourself on your own workload.

The process we followed in this episode is the same process you should follow for any JVM upgrade. Understand the change surface honestly, including what is new and what predates this release. Check compatibility before benchmarking. Run the comparison under the best-controlled conditions your harness supports. Read the results honestly, including the variance and the gaps. Apply the go/no-go checklist. Test the rollback path. Then decide.

For the AcmeCorp platform, the benchmark results are clear and reproducible: Java 25 shows a systematic throughput reduction of approximately 18 percent and a tail latency increase of 20 to 30 percent on this workload. That does not make Java 25 the wrong choice for the long term, but it does mean the upgrade requires further investigation before it can be recommended for production.

That distinction matters. A process that tells you what still needs to happen is more useful than one that declares victory prematurely. The checklist is not a formality. It is the thing that keeps a promising benchmark result from becoming a production incident.

Upgrades are decisions. Make them with evidence.
