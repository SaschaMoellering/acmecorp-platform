# Episode 6 — Java in Containers: AppCDS, Native Images & CRaC

## Opening – Why JVM startup matters in containers

In Episode 5, we fixed the N+1 problem and saw how observability helps us measure performance improvements. But there's another performance problem we haven't talked about yet: startup time.

In traditional deployments, startup time doesn't matter much. You start a service once, it runs for weeks or months, and the startup cost is amortized over millions of requests. But in containerized environments—especially with autoscaling, rolling deployments, and serverless workloads—startup time becomes critical.

The JVM is not slow by accident. It's slow for concrete, observable reasons: class loading, bytecode verification, JIT compilation, and runtime warmup. In this episode, we're going to look at three fundamentally different approaches to solving this problem: AppCDS, native images with GraalVM, and CRaC.

These are not competing technologies. They're tools for different operational constraints. Let's understand what each one does, what it costs, and when to use it.

---

## Understanding JVM startup – Where does the time go?

**[DIAGRAM: E06-D01-jvm-startup-phases]**

Before we optimize anything, we need to understand what's actually happening during JVM startup. Let me start the orders-service and watch what happens.

```bash
time docker run --rm local-orders-service
```

The service takes several seconds to start. But what's happening during those seconds?

First, the JVM loads classes. Spring Boot applications load thousands of classes—Spring framework classes, application classes, dependency classes. Each class has to be read from disk, parsed, verified, and linked.

Second, the JVM initializes static fields and runs static initializers. Spring Boot does a lot of work here—component scanning, bean instantiation, dependency injection, auto-configuration.

Third, the JVM starts JIT compilation. The interpreter runs the bytecode initially, and the JIT compiler identifies hot methods and compiles them to native code. This happens in the background, but it affects performance until the application is fully warmed up.

All of this takes time. And in a containerized environment where services start and stop frequently, this cost is paid over and over again.

---

## Approach 1: AppCDS – Optimizing class loading

**[DIAGRAM: E06-D02-appcds-classloading]**

The first approach is AppCDS—Application Class-Data Sharing. This is a JVM feature that pre-processes classes and stores them in a shared archive. When the JVM starts, it memory-maps the archive instead of loading and parsing classes from scratch.

AppCDS doesn't change the execution model. It's still the same JVM, still running bytecode, still using the JIT compiler. It just makes class loading faster.

Let me switch to the CDS branch and show you how it works.

```bash
git checkout cds
```

Look at the Dockerfile. We've added a multi-stage build that generates the CDS archive during the image build.

```dockerfile
# Training run to generate class list
RUN java -XX:DumpLoadedClassList=/tmp/app.classlist \
    -Dspring.context.exit=onRefresh \
    -jar /tmp/app.jar

# Generate CDS archive from class list
RUN java -Xshare:dump \
    -XX:SharedClassListFile=/tmp/app.classlist \
    -XX:SharedArchiveFile=/opt/app/app.jsa \
    -jar /tmp/app.jar
```

The first step runs the application with `-XX:DumpLoadedClassList`. This records which classes are loaded during startup. The second step uses that list to generate a CDS archive with `-Xshare:dump`.

Now look at the entrypoint. We've added `-Xshare:on` and `-XX:SharedArchiveFile` to tell the JVM to use the archive.

```dockerfile
ENTRYPOINT ["sh","-c","exec java -Xshare:on -XX:SharedArchiveFile=/opt/app/app.jsa $(cat /opt/app/jvm.options) org.springframework.boot.loader.launch.JarLauncher"]
```

Let me build this image and compare startup times.

```bash
docker build -t orders-service-cds .
time docker run --rm orders-service-cds
```

The startup time is noticeably faster—maybe 20-30% improvement. That's significant, but it's not a dramatic change. Why?

Because AppCDS only optimizes class loading. It doesn't help with static initialization, bean creation, or JIT warmup. Those phases still take the same amount of time.

AppCDS is a low-risk optimization. It doesn't change the execution model, it doesn't require code changes, and it works with any JVM-based framework. But it only addresses one part of the startup problem.

---

## Approach 2: Native Images – Changing the execution model

**[DIAGRAM: E06-D03-native-vs-jvm-execution]**

The second approach is native images with GraalVM. This is fundamentally different. Instead of running bytecode on the JVM, we compile the entire application ahead-of-time to a native executable.

This eliminates class loading entirely—there are no classes to load. It eliminates JIT compilation—the code is already compiled. It eliminates interpreter overhead—the executable runs directly on the CPU.

But it comes with significant trade-offs. Let me switch to the GraalVM branch and show you.

```bash
git checkout graalvm
```

Look at the pom.xml. We've added the native-maven-plugin and configured it for Spring Boot.

```xml
<plugin>
    <groupId>org.graalvm.buildtools</groupId>
    <artifactId>native-maven-plugin</artifactId>
    <version>0.9.28</version>
    <configuration>
        <imageName>${project.artifactId}</imageName>
        <buildArgs>
            <arg>--no-fallback</arg>
            <arg>-H:+ReportExceptionStackTraces</arg>
        </buildArgs>
    </configuration>
</plugin>
```

Now look at the Dockerfile. The build process is completely different.

```dockerfile
FROM ghcr.io/graalvm/native-image-community:21-muslib AS build
WORKDIR /workspace
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -q dependency:resolve
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -ntp -Pnative native:compile
```

We're using a GraalVM native-image builder. The build takes significantly longer—5 to 10 minutes instead of 30 seconds. The native-image compiler analyzes the entire application, performs closed-world analysis, and generates a native executable.

Let me build this and compare startup times.

```bash
docker build -t orders-service-native .
time docker run --rm orders-service-native
```

The startup time is dramatically faster—under a second. This is a 10x improvement over the baseline JVM.

But look at the image size. The native image is smaller because it doesn't include the JVM, but the build process is much more complex. And there are runtime limitations.

Native images use a closed-world assumption. All classes must be known at build time. Reflection, dynamic proxies, and resource loading require explicit configuration. Some libraries don't work at all.

Spring Boot has excellent native image support, but not every framework does. If you're using libraries that rely heavily on reflection or dynamic class loading, native images might not be an option.

Native images are a high-reward, high-risk optimization. They deliver dramatic startup improvements, but they require careful testing and may not work with all code.

---

## Approach 3: CRaC – Shifting startup cost in time

**[DIAGRAM: E06-D04-crac-checkpoint-restore-flow]**

The third approach is CRaC—Coordinated Restore at Checkpoint. This is the most interesting one because it doesn't optimize startup—it eliminates it.

The idea is simple: start the application, let it warm up completely, then checkpoint the entire process to disk. When you need to start the service, restore from the checkpoint instead of starting from scratch.

This shifts the startup cost from runtime to build time. You pay the cost once during the image build, then every container starts instantly from the checkpoint.

Let me switch to the CRaC branch and show you.

```bash
git checkout crac
```

Look at the Dockerfile. We're using a CRaC-enabled JVM from Azul.

```dockerfile
FROM azul/zulu-openjdk:21-jdk-crac-latest AS build
```

The build process includes a checkpoint step.

```dockerfile
# Start application and create checkpoint
RUN java -XX:CRaCCheckpointTo=/opt/app/crac-checkpoint \
    -Dspring.context.exit=onRefresh \
    -jar /tmp/app.jar
```

This starts the application, lets Spring Boot initialize completely, then creates a checkpoint. The checkpoint includes the entire JVM state—heap, stack, loaded classes, JIT-compiled code, everything.

Now look at the entrypoint. Instead of starting the JVM, we restore from the checkpoint.

```dockerfile
ENTRYPOINT ["sh","-c","exec java -XX:CRaCRestoreFrom=/opt/app/crac-checkpoint"]
```

Let me build this and compare startup times.

```bash
docker build -t orders-service-crac .
time docker run --rm orders-service-crac
```

The startup time is nearly instant—under 100 milliseconds. This is a 50x improvement over the baseline JVM.

But CRaC has constraints. The checkpoint includes network connections, file handles, and thread state. When you restore, those resources might not be valid anymore. Spring Boot has CRaC support that handles this gracefully, but not all frameworks do.

CRaC also requires careful coordination with the container runtime. You can't checkpoint arbitrary processes—the application has to be CRaC-aware.

CRaC is a high-reward, medium-risk optimization. It delivers the best startup times, but it requires framework support and careful handling of stateful resources.

---

## Comparing the three approaches – Trade-offs and constraints

Let me summarize the three approaches and their trade-offs.

AppCDS optimizes class loading. It's low-risk, requires no code changes, and works with any JVM framework. But it only improves startup by 20-30%. Use AppCDS when you want a safe, incremental improvement.

Native images eliminate the JVM entirely. They deliver 10x startup improvements and smaller image sizes. But they require closed-world analysis, may not work with all libraries, and have longer build times. Use native images when startup time is critical and you can accept the constraints.

CRaC shifts startup cost to build time. It delivers 50x startup improvements and preserves full JVM semantics. But it requires framework support and careful handling of stateful resources. Use CRaC when you need instant startup and your framework supports it.

There's no silver bullet. Each approach solves a different part of the problem. In some cases, you might even combine them—AppCDS with CRaC, for example.

---

## When does startup time actually matter?

Before you optimize startup, ask yourself: does it actually matter?

If you're running long-lived services that start once and run for days, startup time doesn't matter. The cost is amortized over millions of requests.

If you're running autoscaling workloads that start and stop frequently, startup time matters a lot. Every second of startup is a second where the service can't handle traffic.

If you're running serverless functions that start on every invocation, startup time is critical. Native images or CRaC might be the only viable options.

Measure first. Use the observability tools from Episode 4 to understand your actual startup patterns. Then choose the optimization that fits your constraints.

---

## Practical considerations – Build complexity and operational risk

Each optimization adds complexity to your build and deployment pipeline.

AppCDS requires a training run during the image build. You need to ensure the training run exercises the same code paths as production. If your application behavior changes significantly, you might need to regenerate the CDS archive.

Native images require a specialized build environment and significantly longer build times. You need to test thoroughly because some code that works on the JVM might not work as a native image.

CRaC requires checkpoint/restore support in your container runtime. You need to handle stateful resources carefully and ensure your framework supports CRaC lifecycle hooks.

These are not insurmountable problems, but they're real operational costs. Factor them into your decision.

---

## Closing – Optimization is about trade-offs

JVM startup is not a single problem with a single solution. It's a collection of problems—class loading, initialization, JIT warmup—and each optimization addresses a different part.

AppCDS optimizes class loading. Native images eliminate the JVM. CRaC shifts startup cost in time. Each has different trade-offs, different constraints, and different operational costs.

The right choice depends on your workload, your constraints, and your tolerance for complexity. Measure first, understand the trade-offs, then choose the tool that fits.

In the next episode, we'll look at another performance topic: virtual threads and how they change the way we think about concurrency in Java. But we can only do that because we understand the execution model—JVM, native, or checkpointed.

You can't optimize what you don't understand. Now we understand.
