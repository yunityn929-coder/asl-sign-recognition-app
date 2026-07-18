#!/usr/bin/env python3
"""
analyze_recognition_log.py — turns CSVs into an accuracy/latency report for
the HiASL gesture recognition MLP. Accepts CSVs from either source (same
schema, freely mixable in one run):
  - the in-app Recognition Test screen (lib/screens/debug/recognition_test_screen.dart),
    pulled off a physical Android device — validates the full pipeline
    (camera -> MethodChannel -> Android MediaPipe -> TFLite).
  - asl-gesture-recognition-model/static/live_recognition_test.py, run
    directly against a laptop webcam — faster iteration on model accuracy
    alone, no phone/Flutter build required, same MediaPipe config and
    normalization as the app.

See docs/GESTURE_TESTING_PROTOCOL.md for how the input CSVs are produced.

Usage:
    pip install pandas matplotlib
    python3 analyze_recognition_log.py test_data/*.csv
    python3 analyze_recognition_log.py test_data/*.csv --outdir report/

Input CSV schema (one row per processed camera frame during a test session):
    timestamp_ms, target_letter, top_label, top_confidence, second_label,
    second_confidence, hand_detected, is_confident, correct, latency_ms

`target_letter` is tester-declared ground truth (whatever grid button was
selected on screen), NOT derived from the model — that's what makes this
usable for accuracy measurement rather than just self-reported confidence.

Outputs (written to --outdir, default: alongside the first input file):
    analysis_report.md   — overall + per-letter accuracy, latency, confusion
                            highlights, per-session-tag breakdown
    confusion_matrix.png — 36x36 heatmap, target_letter (rows) vs top_label (cols)
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

SIGN_LABELS = [str(d) for d in range(10)] + [chr(c) for c in range(ord("A"), ord("Z") + 1)]

FILENAME_RE = re.compile(r"hiasl_recotest_(.+?)_(\d+)\.csv$")


def session_tag_from_filename(path: str) -> str:
    m = FILENAME_RE.search(os.path.basename(path))
    return m.group(1) if m else os.path.basename(path)


def load(paths: list[str]) -> pd.DataFrame:
    frames = []
    for p in paths:
        df = pd.read_csv(p)
        required = {
            "timestamp_ms", "target_letter", "top_label", "top_confidence",
            "second_label", "second_confidence", "hand_detected",
            "is_confident", "correct", "latency_ms",
        }
        missing = required - set(df.columns)
        if missing:
            print(f"WARNING: {p} missing columns {missing}, skipping", file=sys.stderr)
            continue
        df["session_tag"] = session_tag_from_filename(p)
        df["source_file"] = os.path.basename(p)
        frames.append(df)
    if not frames:
        raise SystemExit("No valid input CSVs.")
    combined = pd.concat(frames, ignore_index=True)
    # bool columns come back from CSV as the strings "True"/"False"
    for col in ("hand_detected", "is_confident", "correct"):
        if combined[col].dtype == object:
            combined[col] = combined[col].map({"True": True, "False": False}).fillna(combined[col])
    return combined


def build_report(df: pd.DataFrame) -> str:
    lines: list[str] = []
    total = len(df)
    detected = df[df["hand_detected"] == True]  # noqa: E712
    no_hand = total - len(detected)

    lines.append("# HiASL Gesture Recognition — Real-World Test Report\n")
    lines.append(f"Total frames logged: **{total}** across {df['source_file'].nunique()} session file(s), "
                  f"{df['session_tag'].nunique()} tag(s).\n")
    lines.append(f"Frames with no hand detected: **{no_hand}** "
                  f"({100 * no_hand / total:.1f}%) — high values here point at MediaPipe "
                  f"detection issues (lighting, framing), not the MLP classifier.\n")

    if len(detected) == 0:
        lines.append("\nNo frames with a detected hand — nothing further to report.\n")
        return "\n".join(lines)

    overall_acc = detected["correct"].mean() * 100
    lines.append(f"## Overall accuracy (hand-detected frames only): **{overall_acc:.1f}%** "
                  f"({int(detected['correct'].sum())}/{len(detected)})\n")
    lines.append("Compare against the 100.00% Colab validation accuracy in TECH_STACK.md — "
                  "the gap here is the real-world generalization cost.\n")

    # Per-letter accuracy
    lines.append("## Per-letter accuracy (sorted worst first)\n")
    lines.append("| Letter | Correct | Attempts | Accuracy |")
    lines.append("|---|---|---|---|")
    per_letter = (
        detected.groupby("target_letter")["correct"]
        .agg(["sum", "count"])
        .rename(columns={"sum": "correct", "count": "attempts"})
    )
    per_letter["accuracy"] = per_letter["correct"] / per_letter["attempts"] * 100
    per_letter = per_letter.reindex([l for l in SIGN_LABELS if l in per_letter.index])
    per_letter = per_letter.sort_values("accuracy")
    for letter, row in per_letter.iterrows():
        flag = " ⚠️" if letter in ("J", "Z") else ""
        lines.append(f"| {letter}{flag} | {int(row['correct'])} | {int(row['attempts'])} | {row['accuracy']:.1f}% |")

    missing_letters = [l for l in SIGN_LABELS if l not in per_letter.index]
    if missing_letters:
        lines.append(f"\nNo data collected for: {', '.join(missing_letters)} — "
                      "re-run a session covering these.\n")

    # Confidence distribution
    lines.append("\n## Confidence distribution (top_confidence, hand-detected frames)\n")
    correct_conf = detected[detected["correct"] == True]["top_confidence"]  # noqa: E712
    wrong_conf = detected[detected["correct"] == False]["top_confidence"]  # noqa: E712
    lines.append("| | mean | median | min | max |")
    lines.append("|---|---|---|---|---|")
    if len(correct_conf):
        lines.append(f"| Correct predictions | {correct_conf.mean():.3f} | {correct_conf.median():.3f} | "
                      f"{correct_conf.min():.3f} | {correct_conf.max():.3f} |")
    if len(wrong_conf):
        lines.append(f"| Wrong predictions | {wrong_conf.mean():.3f} | {wrong_conf.median():.3f} | "
                      f"{wrong_conf.min():.3f} | {wrong_conf.max():.3f} |")
    lines.append(f"\n`kRecognitionConfidenceThreshold` is 0.85. Frames flagged `is_confident=False` "
                 f"are held below that gate: {100 * (~detected['is_confident']).mean():.1f}% of "
                 f"hand-detected frames.\n")

    # Latency
    lines.append("## Latency (`latency_ms` — MediaPipe detection + normalize + TFLite; "
                 "phone sessions also include the MethodChannel round-trip, laptop sessions don't)\n")
    lat = df[df["latency_ms"] >= 0]["latency_ms"]
    if len(lat):
        lines.append("| mean | median | p95 | max |")
        lines.append("|---|---|---|---|")
        lines.append(f"| {lat.mean():.0f}ms | {lat.median():.0f}ms | {lat.quantile(0.95):.0f}ms | {lat.max():.0f}ms |")
        lines.append(f"\nTarget: feedback latency ≤ 1000ms (TECH_STACK.md). "
                     f"{'✅ within target on average' if lat.mean() <= 1000 else '⚠️ average exceeds target'}.\n")
    else:
        lines.append("No latency data (all rows had latency_ms = -1 — logged before the "
                     "latencyMs instrumentation was added, or the field wasn't populated).\n")

    # Per-session breakdown
    if df["session_tag"].nunique() > 1:
        lines.append("## Accuracy by session/condition\n")
        lines.append("| Session tag | Accuracy | Attempts | Mean latency |")
        lines.append("|---|---|---|---|")
        for tag, g in df.groupby("session_tag"):
            g_detected = g[g["hand_detected"] == True]  # noqa: E712
            if len(g_detected) == 0:
                continue
            acc = g_detected["correct"].mean() * 100
            mean_lat = g[g["latency_ms"] >= 0]["latency_ms"].mean()
            lat_str = f"{mean_lat:.0f}ms" if pd.notna(mean_lat) else "—"
            lines.append(f"| {tag} | {acc:.1f}% | {len(g_detected)} | {lat_str} |")

    # Most-confused pairs
    lines.append("\n## Most-confused pairs (target → predicted, wrong only)\n")
    wrong = detected[detected["correct"] == False]  # noqa: E712
    if len(wrong):
        confused = (
            wrong.groupby(["target_letter", "top_label"]).size()
            .sort_values(ascending=False)
            .head(15)
        )
        lines.append("| Target | Predicted | Count |")
        lines.append("|---|---|---|")
        for (target, pred), count in confused.items():
            lines.append(f"| {target} | {pred if pred else '(no confident pred)'} | {count} |")
    else:
        lines.append("No incorrect predictions logged.\n")

    return "\n".join(lines)


def plot_confusion_matrix(df: pd.DataFrame, outpath: str) -> None:
    detected = df[df["hand_detected"] == True]  # noqa: E712
    if len(detected) == 0:
        return
    labels = [l for l in SIGN_LABELS if l in set(detected["target_letter"]) | set(detected["top_label"])]
    if not labels:
        return
    matrix = pd.crosstab(detected["target_letter"], detected["top_label"])
    matrix = matrix.reindex(index=labels, columns=labels, fill_value=0)

    fig, ax = plt.subplots(figsize=(12, 11))
    im = ax.imshow(matrix.values, cmap="Blues")
    ax.set_xticks(range(len(labels)))
    ax.set_yticks(range(len(labels)))
    ax.set_xticklabels(labels, fontsize=7)
    ax.set_yticklabels(labels, fontsize=7)
    ax.set_xlabel("Predicted (top_label)")
    ax.set_ylabel("Target (ground truth)")
    ax.set_title("HiASL Recognition — Confusion Matrix (real-world test data)")
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("csv_files", nargs="+", help="Exported test session CSV(s), supports shell globs")
    parser.add_argument("--outdir", default=None, help="Output directory (default: alongside first input file)")
    args = parser.parse_args()

    outdir = args.outdir or os.path.dirname(os.path.abspath(args.csv_files[0]))
    os.makedirs(outdir, exist_ok=True)

    df = load(args.csv_files)
    report = build_report(df)

    report_path = os.path.join(outdir, "analysis_report.md")
    with open(report_path, "w") as f:
        f.write(report)

    cm_path = os.path.join(outdir, "confusion_matrix.png")
    plot_confusion_matrix(df, cm_path)

    print(f"Wrote {report_path}")
    print(f"Wrote {cm_path}")


if __name__ == "__main__":
    main()
