# Mermaid Diagram Style Guide

This guide defines the practical Mermaid standards for the AcmeCorp course.

Use it to keep diagrams:
- visually consistent across episodes
- readable on slides
- technically honest
- fast to author and review

This is not a generic Mermaid guide. It is the house style for this repository.

## Goals

- Prefer clear teaching diagrams over exhaustive diagrams.
- Optimize for slide readability first, repository neatness second.
- Keep one diagram focused on one decision, one flow, or one comparison.
- Make benchmark diagrams precise without overstating what the data proves.

## Core principles

1. One diagram, one message.
2. Use color to encode category, not decoration.
3. Keep node text short enough to read aloud.
4. Prefer comparison over density.
5. When a benchmark is not JVM-only, say so explicitly.

## Preferred Mermaid types

Use `flowchart` by default.

Use `sequenceDiagram` when:
- the point is interaction order
- the message timing matters more than structure

Use `stateDiagram-v2` when:
- the point is lifecycle state progression
- startup, readiness, or status phases are the core message

Avoid mixing Mermaid diagram types in one file.

## Flow direction rules

Use `flowchart LR` for:
- side-by-side comparisons
- benchmark branch comparisons
- tradeoff summaries
- architecture diagrams with a left-to-right request path

Use `flowchart TB` for:
- layered architecture
- phased startup sequences
- build-time vs runtime breakdowns
- compact slide layouts with a title block on top

If the diagram feels too wide for a slide, switch from `LR` to `TB` before adding more text.

## Color and role mapping

These colors are already used widely in the repo and should remain stable.

### Java generation colors

- `java11`
  - fill `#FEE2E2`
  - stroke `#DC2626`
  - text `#450A0A`
- `java17`
  - fill `#FEF3C7`
  - stroke `#F59E0B`
  - text `#3B1F00`
- `java21`
  - fill `#DCFCE7`
  - stroke `#16A34A`
  - text `#052E16`
- `java25`
  - fill `#E0E7FF`
  - stroke `#4338CA`
  - text `#1E1B4B`

### Generic node roles

- `metric`
  - benchmark title, method, measured winner, compact status
  - fill `#DBEAFE`, stroke `#2563EB`, text `#0F172A`
- `neutral`
  - scope, source, notes, caveats, takeaway
  - fill `#F3F4F6`, stroke `#9CA3AF`, text `#111827`
- `client`
  - users, browser, caller
  - same palette as `neutral`
- `gateway` or primary entrypoint
  - same palette as `metric`
- `service`
  - backend services
  - fill `#DCFCE7`, stroke `#16A34A`, text `#052E16`
- `infra`
  - database, cache, queue, infra layer
  - fill `#FEF3C7`, stroke `#F59E0B`, text `#3B1F00`
- `observability` or warning emphasis
  - fill `#FEE2E2`, stroke `#DC2626`, text `#450A0A`

## Standard class definitions

Use this block for benchmark and platform-branch diagrams:

```mermaid
%% === AcmeCorp Diagram Style Standard ===
classDef java11 fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A;
classDef java17 fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef java21 fill:#DCFCE7,stroke:#16A34A,stroke-width:2.5px,color:#052E16;
classDef java25 fill:#E0E7FF,stroke:#4338CA,stroke-width:2.5px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;
```

Use this block for service architecture diagrams:

```mermaid
%% === AcmeCorp Diagram Style Standard ===
classDef client fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1px,color:#111827;
classDef gateway fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef service fill:#DCFCE7,stroke:#16A34A,stroke-width:1.5px,color:#052E16;
classDef infra fill:#FEF3C7,stroke:#F59E0B,stroke-width:1.5px,color:#3B1F00;
classDef note fill:#FEE2E2,stroke:#DC2626,stroke-width:1px,color:#450A0A;
```

## Title and subtitle conventions

Every slide-facing diagram should have a compact title node or a clearly named top subgraph.

Title rules:
- Keep the title to 2 lines max.
- Line 1: what the diagram compares or explains.
- Line 2: scope, if needed.

Good examples:
- `Startup Comparison`
- `Platform Branch Tradeoffs`
- `AWS Reference Architecture`
- `JVM Startup Phases`

Subtitle/context rules:
- Use one compact `neutral` or `metric` node for scope.
- Include benchmark methodology only if it changes interpretation.
- Avoid embedding a paragraph into the title node.

## Text density rules

Slide readability rules:
- Prefer 2-3 lines per node.
- Hard limit: 4 lines per node.
- Prefer 3-8 words per line.
- Avoid full sentences inside most nodes.

If a node needs:
- more than 4 lines
- more than 20-25 words
- more than one caveat

split the diagram or move the explanation into teleprompter text.

## Benchmark diagram conventions

Benchmark diagrams must be explicit about scope.

Always include:
- what is being compared
- whether it is a maintained platform branch comparison or a narrower benchmark
- the metric name
- the aggregation method if relevant, usually `Median of 5 runs`
- the data source in a short form

Do not imply a pure JVM benchmark unless the repo actually isolates that variable.

### Recommended wording

Use:
- `Maintained platform branches`
- `Median of 5 runs per branch`
- `External stack readiness`
- `Orders main→ready`
- `orders-service container snapshot`

Avoid:
- `JVM winner`
- `fastest Java overall`
- `proof that newer Java is faster`

## Startup diagram conventions

Startup diagrams should separate:
- external readiness
- in-process application bootstrap

Preferred primary metric:
- `orders-service main→ready`

Supporting metric:
- `gateway readiness`

Labeling rules:
- Say `External readiness` or `Gateway readiness`
- Say `Orders main→ready`
- Avoid generic `startup` unless the diagram contains only one startup metric

## Memory diagram conventions

Memory diagrams should say exactly what is being measured.

Preferred wording:
- `orders-service container RSS snapshot after readiness`
- `Median of 5 runs`

Avoid:
- `memory usage` without context
- `steady-state memory` unless that is truly what was measured

## Tradeoff diagram conventions

Use tradeoff diagrams when:
- there is no single winner
- different branches lead different metrics
- the teaching point is decision-making, not ranking

Tradeoff diagrams should:
- show one winner per metric
- keep one metric per visual lane or pair
- end with a compact takeaway node

Good takeaway wording:
- `No single winner`
- `Tradeoff story, not a ranking story`
- `Choose by operational priority`

## Architecture diagram conventions

Architecture diagrams should:
- show boundaries first
- show request path second
- show infra dependencies third

Prefer:
- `TB` for layered views
- `LR` for request-path views

Use subgraphs when:
- the boundary matters to the story
- the layer meaning helps the audience

Avoid using subgraphs only for decoration.

## Best-value highlighting rules

Highlight best values with:
- the branch color
- position
- compact metric wording

Do not:
- add stars, trophies, or exaggerated callouts
- imply that a winner on one metric is the overall winner

If there is no single winner, show separate metric winners rather than forcing a rank.

## Source labeling rules

Source nodes should be short.

Preferred forms:
- `summary.md + orders-startup.json`
- `containers.json`
- `load.json`

If a source node takes more than 3 lines, move the detail into the teleprompter.

## When to split a diagram into two

Split a diagram when any of these are true:
- it compares more than 4 branches and more than 2 metrics
- the title node requires a paragraph
- the audience must learn both process and result at once
- architecture and benchmark interpretation are being mixed

Typical split patterns:
- `comparison diagram` + `tradeoff summary diagram`
- `startup phases` + `measured startup results`
- `architecture overview` + `request flow`

## File naming conventions

Use:
- `E##-D##-short-topic.md`

Examples:
- `E07-D01-startup-comparison.md`
- `E07-D03-platform-tradeoffs.md`

Keep filenames:
- lowercase
- hyphen-separated
- short and specific

## Recommended author checklist

Before committing a Mermaid diagram, verify:

1. Can the message be understood in under 10 seconds on a slide?
2. Is the diagram explicit about benchmark scope?
3. Are node labels short enough to read aloud?
4. Is the color meaning consistent with the repo?
5. Does the diagram overclaim what the benchmark proves?
6. Would splitting the diagram improve teaching clarity?

## Default patterns by diagram type

### Benchmark comparison
- Title node
- Method/scope node
- 3-4 branch nodes in one row
- Source/status node

### Tradeoff summary
- Title node
- Scope node
- One winner pair per metric
- Short takeaway node

### Architecture overview
- Top-level boundary grouping
- Client/gateway/services/infra mapping
- Minimal text in each node

### Startup/lifecycle
- Top-to-bottom progression
- One phase per node
- Optional note nodes only when critical to interpretation

## Final rule

If the audience would need narration just to parse the diagram structure, the diagram is too dense.

In that case:
- reduce text
- reduce node count
- or split the diagram

