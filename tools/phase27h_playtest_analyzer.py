#!/usr/bin/env python3
"""Phase 27H-R0 Playtest Analyzer — reads schema-v2 JSONL and produces advisory Markdown."""

from __future__ import annotations

import argparse
import json
import statistics
from collections import Counter, defaultdict
from pathlib import Path


def load_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError(f"line {line_number}: malformed JSON: {exc.msg}") from exc
        if not isinstance(value, dict):
            raise ValueError(f"line {line_number}: expected JSON object")
        rows.append(value)
    return rows


def validate_runs(rows: list[dict], matrix: dict, require_complete: bool = False) -> list[str]:
    expected = {entry["run_label"]: entry for entry in matrix.get("runs", [])}
    seen: set[str] = set()
    errors: list[str] = []
    for index, row in enumerate(rows, 1):
        label = str(row.get("run_label", ""))
        if int(row.get("schema_version", 0)) != 2:
            errors.append(f"row {index}: schema_version must be 2")
        if label in seen:
            errors.append(f"row {index}: duplicate run_label {label}")
        seen.add(label)
        if label not in expected:
            errors.append(f"row {index}: unknown run_label {label}")
            continue
        target = expected[label]
        if str(row.get("style_id", "")) != str(target["style_id"]):
            errors.append(f"row {index}: style mismatch for {label}")
        if int(row.get("seed", -1)) != int(target["seed"]):
            errors.append(f"row {index}: seed mismatch for {label}")
    if require_complete:
        missing = sorted(set(expected) - seen)
        if missing:
            errors.append("missing matrix runs: " + ", ".join(missing))
    return errors


def _median(rows: list[dict], key: str) -> float:
    values = [float(row.get(key, 0)) for row in rows]
    return statistics.median(values) if values else 0.0


def _side_metric(row: dict, side: str, metric: str) -> int:
    economy = row.get("command_economy", {})
    if not isinstance(economy, dict):
        return 0
    side_value = economy.get(side, {})
    if not isinstance(side_value, dict):
        return 0
    return int(side_value.get(metric, 0))


def summarize(rows: list[dict], matrix: dict) -> str:
    expected_count = len(matrix.get("runs", []))
    by_style: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_style[str(row.get("style_id", "unclassified"))].append(row)

    lines = [
        "# Phase 27H Playtest Analysis",
        "",
        "## Collection Completeness",
        "",
        f"- Collected: {len(rows)}/{expected_count}",
        "",
        "## Per-Run Results",
        "",
        "| Run | Style | Seed | Result | Player turns | Advisory |",
        "|---|---:|---:|---|---:|---|",
    ]
    for row in sorted(rows, key=lambda item: str(item.get("run_label", ""))):
        advisory = row.get("pacing_advisory", {})
        advisory_label = advisory.get("label", "unclassified") if isinstance(advisory, dict) else "unclassified"
        lines.append(
            "| {run} | {style} | {seed} | {result} | {turns} | {advisory} |".format(
                run=row.get("run_label", ""),
                style=row.get("style_id", ""),
                seed=row.get("seed", -1),
                result=row.get("result", "unknown"),
                turns=row.get("player_turn_count", 0),
                advisory=advisory_label,
            )
        )

    style_titles = [
        ("heat_burst", "Heat Burst"),
        ("control", "Control"),
        ("hero_synergy", "Hero Synergy"),
    ]
    for style_id, title in style_titles:
        group = by_style.get(style_id, [])
        turns = [int(row.get("player_turn_count", 0)) for row in group]
        style_unused = [_side_metric(row, "player", "unused") for row in group]
        style_phase2 = [int(row.get("phase_entry_turns", {}).get("2", 0)) for row in group if str(row.get("phase_entry_turns", {}).get("2", "")) != ""]
        style_phase3 = [int(row.get("phase_entry_turns", {}).get("3", 0)) for row in group if str(row.get("phase_entry_turns", {}).get("3", "")) != ""]
        style_damage: Counter[str] = Counter()
        style_skills: Counter[str] = Counter()
        style_stops: Counter[str] = Counter()
        for row in group:
            style_damage.update(row.get("damage_by_source", {}))
            style_skills.update(row.get("hero_skill_uses", {}))
            style_stops.update(row.get("boss_stop_reasons", {}))
        style_damage_total = sum(style_damage.values())
        style_damage_text = ", ".join(
            f"{key}={value} ({value / style_damage_total:.1%})"
            for key, value in sorted(style_damage.items())
        ) if style_damage_total else "None"
        lines.extend([
            "",
            f"## {title}",
            "",
            f"- Runs: {len(group)}",
            f"- Wins / defeats: {sum(row.get('result') == 'victory' for row in group)} / {sum(row.get('result') == 'defeat' for row in group)}",
            f"- Player turns median / min / max: {statistics.median(turns) if turns else 0} / {min(turns) if turns else 0} / {max(turns) if turns else 0}",
            f"- Median max Depth: {_median(group, 'max_depth')}",
            f"- Total Backlash: {sum(int(row.get('backlash_trigger_count', 0)) for row in group)}",
            f"- Median unused player command points: {statistics.median(style_unused) if style_unused else 0}",
            f"- Phase 2 / Phase 3 median player turn: {statistics.median(style_phase2) if style_phase2 else 'not reached'} / {statistics.median(style_phase3) if style_phase3 else 'not reached'}",
            f"- Damage source shares: {style_damage_text}",
            "- Hero skill uses: " + (", ".join(f"{key}={value}" for key, value in sorted(style_skills.items())) or "None"),
            "- Boss stop reasons: " + (", ".join(f"{key}={value}" for key, value in sorted(style_stops.items())) or "None"),
            f"- No-progress flags: {sum(len(row.get('no_progress_rounds', [])) for row in group)}",
        ])

    spent = sum(_side_metric(row, "player", "spent") for row in rows)
    refunded = sum(_side_metric(row, "player", "refunded") for row in rows)
    unused = sum(_side_metric(row, "player", "unused") for row in rows)
    gained = sum(_side_metric(row, "player", "gained") for row in rows)
    phase2 = [int(row.get("phase_entry_turns", {}).get("2", 0)) for row in rows if str(row.get("phase_entry_turns", {}).get("2", "")) != ""]
    phase3 = [int(row.get("phase_entry_turns", {}).get("3", 0)) for row in rows if str(row.get("phase_entry_turns", {}).get("3", "")) != ""]
    stop_reasons: Counter[str] = Counter()
    invalid_reasons: Counter[str] = Counter()
    damage_sources: Counter[str] = Counter()
    hero_skills: Counter[str] = Counter()
    monster_deploys: Counter[str] = Counter()
    route_starts: Counter[str] = Counter()
    route_completions: Counter[str] = Counter()
    od_zone_entries: Counter[str] = Counter()
    for row in rows:
        stop_reasons.update(row.get("boss_stop_reasons", {}))
        invalid_reasons.update(row.get("invalid_reasons", {}))
        damage_sources.update(row.get("damage_by_source", {}))
        hero_skills.update(row.get("hero_skill_uses", {}))
        monster_deploys.update(row.get("monster_deploy_counts", {}))
        route_starts.update(row.get("route_start_counts", {}))
        route_completions.update(row.get("route_complete_counts", {}))
        od_zone_entries.update(row.get("od_zone_entries", {}))

    lines.extend([
        "",
        "## Resource and Command Economy",
        "",
        f"- Player gained / spent / refunded / unused: {gained} / {spent} / {refunded} / {unused}",
        "- Damage by source: " + (", ".join(f"{key}={value}" for key, value in sorted(damage_sources.items())) or "None"),
        "- Hero skill uses: " + (", ".join(f"{key}={value}" for key, value in sorted(hero_skills.items())) or "None"),
        "- Monster deployments: " + (", ".join(f"{key}={value}" for key, value in sorted(monster_deploys.items())) or "None"),
        "- Route starts: " + (", ".join(f"{key}={value}" for key, value in sorted(route_starts.items())) or "None"),
        "- Route completions: " + (", ".join(f"{key}={value}" for key, value in sorted(route_completions.items())) or "None"),
        "- OD zone entries: " + (", ".join(f"{key}={value}" for key, value in sorted(od_zone_entries.items())) or "None"),
        f"- Depth recovery count / amount: {sum(int(row.get('depth_recovery_count', 0)) for row in rows)} / {sum(int(row.get('depth_recovery_amount', 0)) for row in rows)}",
        f"- Route abandon count: {sum(int(row.get('route_abandon_count', 0)) for row in rows)}",
        "",
        "## Boss Phase Timing",
        "",
        f"- Phase 2 median player turn: {statistics.median(phase2) if phase2 else 'not reached'}",
        f"- Phase 3 median player turn: {statistics.median(phase3) if phase3 else 'not reached'}",
        "",
        "## No-Progress Diagnostics",
        "",
        f"- Flag count: {sum(len(row.get('no_progress_rounds', [])) for row in rows)}",
        "",
        "## Invalid Action Reasons",
        "",
        "- " + (", ".join(f"{key}={value}" for key, value in sorted(invalid_reasons.items())) or "None"),
        "",
        "## Advisory Observations",
        "",
        "- Turn bands are descriptive only; no run fails because it is faster or slower.",
        "- Boss stop reasons: " + (", ".join(f"{key}={value}" for key, value in sorted(stop_reasons.items())) or "None"),
        "",
        "## Candidate Tuning Questions",
        "",
        "- Are quick wins produced by earned route/skill conversion or repeated ordinary attacks?",
        "- Are long games still making board, resource, or phase progress?",
        "- Does one command, skill, or defensive loop dominate all three styles?",
    ])
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--matrix", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args(argv)
    try:
        rows = load_jsonl(args.input)
        matrix = json.loads(args.matrix.read_text(encoding="utf-8"))
        errors = validate_runs(rows, matrix, args.require_complete)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}")
        return 2
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(summarize(rows, matrix), encoding="utf-8")
    print(f"Phase 27H report written: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
