This radar chart shows normalized relative strengths, not raw benchmark numbers. Each axis is scaled from `0` to `100`, where `100` is the strongest branch on that dimension within this Episode 7 benchmark set.

```mermaid
radar-beta
title Platform Branch Benchmark Tradeoffs - Java 11 vs 17 vs 21 vs 25

axis startup["Startup (0-100)"]
axis memory["Memory Efficiency (0-100)"]
axis throughput["Throughput (0-100)"]
axis bootstrap["Internal Bootstrap (0-100)"]

%% Relative strength scores normalized from the 5-run medians.
%% Higher is better on every axis.
%% Startup + Internal Bootstrap invert lower-is-better timings.
%% Memory Efficiency inverts lower-is-better memory footprint.

curve java11["Java 11"]{34, 0, 100, 92}
curve java17["Java 17"]{4, 100, 74, 0}
curve java21["Java 21"]{100, 93, 47, 40}
curve java25["Java 25"]{0, 82, 0, 100}
```
