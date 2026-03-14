# Episode 7 – Benchmark and Documentation Status

## Executive Summary

Episode 7 now presents a maintained platform branch comparison across Java 11, Java 17, Java 21, and Java 25. The benchmark refresh workflow completed successfully and produced a 5-run median result set that is stored in the repository. The teleprompter has been refined so that it no longer frames the results as a pure JVM-only comparison, and it now treats `orders-service main-to-ready` as the primary startup metric. The Mermaid benchmark diagrams were updated to reflect the measured medians and to describe the benchmark as a maintained platform branch comparison. A new tradeoff diagram was added to make the benchmark story easier to understand on slides: different branches lead different metrics. The repository also now contains a Mermaid diagram style guide and reusable templates, which means the Episode 7 visual language is aligned with a broader course-level standard. Based on the current repository state, all five improvement areas are implemented: teleprompter narrative refinement, benchmark diagram wording updates, startup comparison visual improvements, tradeoff diagram introduction, and a reusable diagram design system.

---

## Benchmark Results (Median of 5 Runs)

| Java Version | External Readiness | Orders Main-to-Ready | Orders Memory | Throughput |
| --- | --- | --- | --- | --- |
| Java 11 | 10.46s | 15759 ms | 1060.9 MiB | 7281.6 req/s |
| Java 17 | 10.99s | 19154 ms | 578.2 MiB | 6995.6 req/s |
| Java 21 | 9.31s | 17669 ms | 611.5 MiB | 6701.8 req/s |
| Java 25 | 11.06s | 15483 ms | 667.2 MiB | 6193.0 req/s |

---

## Teleprompter Narrative Status

The Episode 7 teleprompter currently frames the benchmark as a maintained platform branch comparison rather than a pure JVM-only comparison. It explicitly states that each branch reflects a platform generation that includes Java version, framework version, packaging, and configuration. It treats `orders-service main-to-ready` as the primary startup metric, while external readiness, memory footprint, and throughput are presented as supporting metrics. It also explicitly says that the results are a tradeoff story rather than a “newer always wins” story, which keeps the benchmark narrative technically honest. This improvement area is completed.

Teleprompter file:
- [Teleprompter-Script-Episode-7-Polished.md](/home/videouser/development/acme/acmecorp-platform/docs/episodes/episode-07/Teleprompter-Script-Episode-7-Polished.md)

---

## Mermaid Diagram Updates

The Episode 7 diagrams now support the benchmark narrative visually. They present the measured medians, distinguish the benchmark metrics clearly, and keep the scope aligned with maintained platform branches rather than implying a pure JVM-only ranking. The diagram wording and slide-readability improvements are implemented, and the tradeoff diagram addition is also present in the repository.

### E07-D01 Startup Comparison

This diagram shows the two startup-related metrics used in Episode 7: external readiness and `orders-service main-to-ready`. It explicitly describes the comparison as one across maintained platform branches and states that the values are medians of 5 cold starts per branch. It also identifies the data sources used for readiness and in-process bootstrap timing. This improvement area is completed.

File path:
- [E07-D01-startup-comparison.md](/home/videouser/development/acme/acmecorp-platform/docs/episodes/episode-07/assets/diagrams/E07-D01-startup-comparison.md)

### E07-D02 Memory Footprint Comparison

This diagram shows the `orders-service` container RSS snapshot after readiness and makes clear that the memory numbers come from the `orders-service` container specifically. It also states that the values are medians of 5 runs per branch and names the benchmark output file used as the source. This improvement area is completed.

File path:
- [E07-D02-memory-footprint-comparison.md](/home/videouser/development/acme/acmecorp-platform/docs/episodes/episode-07/assets/diagrams/E07-D02-memory-footprint-comparison.md)

### E07-D03 Platform Tradeoffs

This diagram summarizes the fact that different maintained platform branches win different metrics. It shows Java 21 as the fastest for full-stack readiness, Java 25 as the fastest for internal bootstrap, Java 17 as the lowest-memory branch, and Java 11 as the highest-throughput branch. It supports the tradeoff narrative directly and avoids implying that there is a single universal winner. This improvement area is completed.

File path:
- [E07-D03-platform-tradeoffs.md](/home/videouser/development/acme/acmecorp-platform/docs/episodes/episode-07/assets/diagrams/E07-D03-platform-tradeoffs.md)

---

## Benchmark Methodology

The workflow used to generate the current Episode 7 result set is the repository’s canonical refresh script:

```bash
RUNS_PER_BRANCH=5 WARMUP=60 DURATION=120 CONCURRENCY=25 DO_FETCH=0 \
BRANCHES="java11 java17 java21 java25" \
bash bench/run-episode07-refresh.sh
```

The workflow reports medians rather than single-run values, which improves comparability and aligns with the documented methodology used in Episode 7. Raw data is written into per-branch result directories and includes `summary.md`, `orders-startup.json`, `load.json`, and `containers.json`. The consolidated result JSON currently present in the repository is:

- [episode07-median-summary-20260314T103931Z.json](/home/videouser/development/acme/acmecorp-platform/bench/results/episode07-median-summary-20260314T103931Z.json)

This improvement area is completed.

---

## Current Episode 7 Narrative

The current Episode 7 lesson is that platform upgrades shift startup, memory, and throughput differently. Java 21 leads external readiness, Java 25 leads `orders-service main-to-ready`, Java 17 leads orders-service memory footprint, and Java 11 leads throughput. That means the benchmark does not support a simplistic “newer always wins” conclusion. Instead, it supports a practical tradeoff narrative: different maintained platform branches optimize different operational dimensions, and teams need to measure which dimension matters most for their own systems.

---

## Remaining Improvements (Optional)

The core Episode 7 improvements appear to be implemented. Optional follow-up enhancements that are not required for the current benchmark and documentation state could include:

- additional benchmark visualization variants for other slide layouts
- tighter integration of the new tradeoff diagram into the teleprompter or course blueprint
- more explicit documentation of the Mermaid standards from within episode-level authoring docs

The new Mermaid design system files are present in the repository:
- [mermaid-diagram-style-guide.md](/home/videouser/development/acme/acmecorp-platform/docs/standards/mermaid-diagram-style-guide.md)
- [mermaid-templates.md](/home/videouser/development/acme/acmecorp-platform/docs/standards/mermaid-templates.md)

---

## Conclusion

Episode 7 now reads as a practical platform upgrade benchmark rather than as a pure JVM microbenchmark. The benchmark values, teleprompter wording, and Mermaid diagrams are aligned around the same core lesson: maintained platform branches can improve startup, memory, and throughput in different ways, and the right conclusion comes from measured tradeoffs rather than a single universal winner.
