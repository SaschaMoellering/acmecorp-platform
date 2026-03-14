# Benchmark Summary Slide

Use this asset when an episode needs to summarize measured benchmark results on a single presentation slide.

The goal is not to show every number. The goal is to help the viewer understand:
- the primary metric
- the supporting metrics
- the tradeoff pattern
- the practical takeaway

This file is a reusable template. Adapt the labels and values per episode.

## Slide structure

Recommended slide order:

1. Title
2. Primary metric
3. Supporting metrics
4. Tradeoff summary
5. Takeaway

Recommended speaking order:

1. State the main metric first.
2. Name which option wins that metric.
3. Add the supporting metrics only after the audience understands the main result.
4. End with the tradeoff, not with a forced winner.

## Presenter notes

- Use one primary metric only.
- Keep supporting metrics to 2-3.
- If the benchmark is not JVM-only, say so explicitly.
- If there is no single winner, use the takeaway node to say that directly.
- Do not overload the slide with methodology detail. Keep source and method short.

## Reusable Mermaid template

```md
```mermaid
flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef optionA fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef optionB fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#052E16;
classDef optionC fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef optionD fill:#E0E7FF,stroke:#4338CA,stroke-width:2px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;

Title["<b>Benchmark Summary</b><br/>Episode / Topic"]:::metric
Scope["<b>Scope</b><br/>What is being compared<br/>Median of N runs"]:::neutral

Primary["<b>Primary Metric</b><br/>Metric name<br/>Winner + value"]:::metric

subgraph Supporting[" "]
direction LR
S1["<b>Supporting Metric 1</b><br/>Winner + value"]:::neutral
S2["<b>Supporting Metric 2</b><br/>Winner + value"]:::neutral
S3["<b>Supporting Metric 3</b><br/>Winner + value"]:::neutral
end

Tradeoff["<b>Tradeoff</b><br/>What the mixed results mean"]:::neutral
Takeaway["<b>Takeaway</b><br/>What the audience should remember"]:::metric

Title --> Scope --> Primary --> Supporting --> Tradeoff --> Takeaway
```
```

## Reusable benchmark-branch variant

Use this version when the slide needs named branch or runtime winners instead of generic options.

```md
```mermaid
flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef java11 fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A;
classDef java17 fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef java21 fill:#DCFCE7,stroke:#16A34A,stroke-width:2.5px,color:#052E16;
classDef java25 fill:#E0E7FF,stroke:#4338CA,stroke-width:2.5px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;

Title["<b>Benchmark Summary</b><br/>Maintained platform branches"]:::metric
Scope["<b>Scope</b><br/>Primary metric + supporting metrics<br/>Median of N runs per branch"]:::neutral

Primary["<b>Primary Metric</b><br/>Orders main→ready<br/>Java 25: 15483 ms"]:::metric

subgraph Supporting[" "]
direction LR
S1["<b>External Readiness</b><br/>Java 21: 9.31s"]:::neutral
S2["<b>Memory</b><br/>Java 17: 578.2 MiB"]:::neutral
S3["<b>Throughput</b><br/>Java 11: 7281.6 req/s"]:::neutral
end

Tradeoff["<b>Tradeoff</b><br/>Different branches lead different metrics"]:::neutral
Takeaway["<b>Takeaway</b><br/>No single winner<br/>Measure the tradeoffs"]:::metric

Title --> Scope --> Primary --> Supporting --> Tradeoff --> Takeaway
```
```

## Optional Episode 7 example

This example is included to show how the template can be instantiated. Reuse the structure, not the wording.

```md
```mermaid
flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef java11 fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A;
classDef java17 fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef java21 fill:#DCFCE7,stroke:#16A34A,stroke-width:2.5px,color:#052E16;
classDef java25 fill:#E0E7FF,stroke:#4338CA,stroke-width:2.5px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;

Title["<b>Episode 7 Benchmark Summary</b><br/>Maintained platform branches"]:::metric
Scope["<b>Scope</b><br/>5-run medians<br/>Startup, memory, throughput"]:::neutral

Primary["<b>Primary Metric</b><br/>Orders main→ready<br/>Java 25: 15483 ms"]:::metric

subgraph Supporting[" "]
direction LR
S1["<b>External Readiness</b><br/>Java 21: 9.31s"]:::neutral
S2["<b>Orders Memory</b><br/>Java 17: 578.2 MiB"]:::neutral
S3["<b>Throughput</b><br/>Java 11: 7281.6 req/s"]:::neutral
end

Tradeoff["<b>Tradeoff</b><br/>Best branch depends on the metric"]:::neutral
Takeaway["<b>Takeaway</b><br/>No single winner<br/>Platform upgrades are tradeoffs"]:::metric

Title --> Scope --> Primary --> Supporting --> Tradeoff --> Takeaway
```
```

## How to adapt this asset

For each new episode:
- replace the title
- choose one primary metric
- keep the supporting metrics short
- rewrite the takeaway in plain spoken language
- only include source/method wording if it changes interpretation

If the episode has:
- one clear winner: keep the tradeoff node short and make the takeaway operational
- mixed results: make the tradeoff node explicit and avoid ranking language
- too many metrics: split into two slides instead of adding more nodes
