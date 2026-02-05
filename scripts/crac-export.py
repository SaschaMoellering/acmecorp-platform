#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path


def parse_md_table(path: Path):
    lines = [ln.strip() for ln in path.read_text().splitlines() if ln.strip().startswith("|")]
    if len(lines) < 2:
        return [], []
    headers = [c.strip() for c in lines[0].strip("|").split("|")]
    rows = []
    for ln in lines[2:]:
        cols = [c.strip() for c in ln.strip("|").split("|")]
        if len(cols) < len(headers):
            cols += [""] * (len(headers) - len(cols))
        rows.append(cols[: len(headers)])
    return headers, rows


def write_csv(headers, rows, out_path: Path):
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(headers)
        w.writerows(rows)


def extract_stat(value: str, key: str):
    m = re.search(rf"{re.escape(key)}=([0-9]+|N/A)", value)
    return m.group(1) if m else "N/A"

def extract_group(value: str, label: str):
    m = re.search(rf"{re.escape(label)}\(([^)]*)\)", value)
    return m.group(1) if m else ""


def write_summary(args, headers, rows, out_path: Path):
    idx = {h: i for i, h in enumerate(headers)}
    with out_path.open("w") as f:
        f.write("# CRaC Matrix Summary\n\n")
        f.write("## Metadata\n\n")
        f.write(f"- timestamp: `{args.timestamp}`\n")
        f.write(f"- branch: `{args.branch}`\n")
        f.write(f"- commit: `{args.commit}`\n")
        f.write(f"- engine: `{args.engine}`\n")
        f.write(f"- services: `{args.services}`\n")
        f.write(f"- repeats: `{args.repeats}`\n")
        f.write(f"- smoke: `{args.smoke}`\n")
        f.write(f"- smoke_urls: `{args.smoke_urls or '(default)'}`\n")
        f.write(f"- checkpoint_poll_max_seconds: `{args.checkpoint_poll}`\n")
        f.write(f"- restore_poll_max_seconds: `{args.restore_poll}`\n\n")

        f.write("## Restore Timings\n\n")
        f.write("Metrics:\n")
        f.write("- restore_jvm_ms: Spring CRaC marker `restored JVM running for XX ms`\n")
        f.write("- restore_ready_ms: time-to-HTTP-200 for /actuator/health\n")
        f.write("- post_restore_ms: restore_ready_ms - restore_jvm_ms\n\n")

        f.write("| service | restore_ready_ms (median) | restore_jvm_ms (median) | post_restore_ms (median) | p95_ready | p95_jvm | p95_post | restore_stats | reason |\n")
        f.write("|---|---:|---:|---:|---:|---:|---:|---|---|\n")
        for row in rows:
            svc = row[idx.get("service", 0)]
            med_ready = row[idx.get("restore_ready_ms", 0)] if "restore_ready_ms" in idx else "N/A"
            med_jvm = row[idx.get("restore_jvm_ms", 0)] if "restore_jvm_ms" in idx else "N/A"
            med_post = row[idx.get("post_restore_ms", 0)] if "post_restore_ms" in idx else "N/A"
            stats = row[idx.get("restore_stats", 0)] if "restore_stats" in idx else "N/A"
            reason = row[idx.get("reason", 0)]

            ready_stats = extract_group(stats, "ready")
            jvm_stats = extract_group(stats, "jvm")
            post_stats = extract_group(stats, "post")
            p95_ready = extract_stat(ready_stats, "p95") if ready_stats else "N/A"
            p95_jvm = extract_stat(jvm_stats, "p95") if jvm_stats else "N/A"
            p95_post = extract_stat(post_stats, "p95") if post_stats else "N/A"

            f.write(f"| {svc} | {med_ready} | {med_jvm} | {med_post} | {p95_ready} | {p95_jvm} | {p95_post} | {stats} | {reason} |\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--matrix-md", required=True)
    p.add_argument("--csv-out", required=True)
    p.add_argument("--summary-out", required=True)
    p.add_argument("--timestamp", required=True)
    p.add_argument("--branch", required=True)
    p.add_argument("--commit", required=True)
    p.add_argument("--engine", required=True)
    p.add_argument("--services", required=True)
    p.add_argument("--repeats", required=True)
    p.add_argument("--smoke", required=True)
    p.add_argument("--smoke-urls", default="")
    p.add_argument("--checkpoint-poll", required=True)
    p.add_argument("--restore-poll", required=True)
    args = p.parse_args()

    headers, rows = parse_md_table(Path(args.matrix_md))
    if not headers:
        raise SystemExit("matrix markdown table not found")

    write_csv(headers, rows, Path(args.csv_out))
    write_summary(args, headers, rows, Path(args.summary_out))


if __name__ == "__main__":
    main()
