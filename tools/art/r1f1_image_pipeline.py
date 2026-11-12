
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageStat


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art_direction" / "celestial_furnace" / "r1f1"
SPEC = "docs/superpowers/specs/2026-09-01-phase27k-r1f-celestial-furnace-art-direction-design.md"
SPEC_COMMIT = "4cad386035cd69913ff26f05498e53219f4b0c1d"
SIZE = (1920, 1080)
TARGETS = {
    "a01": OUT / "a01_world_key_art_v01.png",
    "a02_base": OUT / "a02_battle_base_view_v01.png",
    "a02_top": OUT / "a02_battle_top_view_v01.png",
    "a03": OUT / "a03_material_bible_v01.png",
    "contact": OUT / "r1f1_contact_sheet_v01.png",
}
MATERIAL_LABELS = (
    "CLOUD LIMESTONE",
    "GRAPHITE IRON",
    "OXIDIZED BRONZE",
    "JADE ENAMEL",
    "FURNACE CRYSTAL",
    "DEPTH CORROSION",
)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf"),
    ):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def _open_rgb(path: Path) -> Image.Image:
    with Image.open(path) as image:
        image.load()
        return image.convert("RGB")


def _fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(
        image,
        size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )


def _label_materials(image: Image.Image) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    font = _font(24)
    cell_w = image.width // 3
    cell_h = image.height // 2
    for index, label in enumerate(MATERIAL_LABELS):
        col = index % 3
        row = index // 3
        x0 = col * cell_w
        y1 = (row + 1) * cell_h
        draw.rectangle((x0, y1 - 50, x0 + cell_w, y1), fill=(5, 8, 12, 205))
        draw.text((x0 + 18, y1 - 39), label, font=font, fill=(235, 240, 244, 255))
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


def normalize(key: str, source: Path) -> None:
    if key not in TARGETS or key == "contact":
        raise SystemExit(f"normalize key must be one of: a01, a02_base, a02_top, a03; got {key}")
    if not source.is_file():
        raise SystemExit(f"input image missing: {source}")
    OUT.mkdir(parents=True, exist_ok=True)
    image = _fit(_open_rgb(source), SIZE)
    if key == "a03":
        image = _label_materials(image)
    target = TARGETS[key]
    image.save(target, format="PNG", optimize=True)
    print(f"NORMALIZED {key}: {target} {image.width}x{image.height}")


def _validate_image(key: str, path: Path) -> list[str]:
    problems: list[str] = []
    if not path.is_file():
        return [f"{key}: missing {path.relative_to(ROOT)}"]
    try:
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG":
                problems.append(f"{key}: format={image.format}, expected PNG")
            if image.size != SIZE:
                problems.append(f"{key}: size={image.size}, expected {SIZE}")
            rgb = image.convert("RGB")
            mean_stddev = sum(ImageStat.Stat(rgb).stddev) / 3.0
            if mean_stddev < 8.0:
                problems.append(f"{key}: near-flat image, mean_stddev={mean_stddev:.2f}")
    except Exception as error:
        problems.append(f"{key}: decode failed: {error}")
    return problems


def validate(keys: list[str]) -> int:
    problems: list[str] = []
    if not (OUT / ".gdignore").is_file():
        problems.append("missing docs/art_direction/celestial_furnace/r1f1/.gdignore")
    for key in keys:
        problems.extend(_validate_image(key, TARGETS[key]))
    if problems:
        for problem in problems:
            print(f"FAIL {problem}")
        return 1
    for key in keys:
        print(f"PASS {key}: {TARGETS[key].relative_to(ROOT)} sha256={_sha256(TARGETS[key])}")
    return 0


def contact_sheet() -> None:
    source_keys = ("a01", "a02_base", "a02_top", "a03")
    missing = [key for key in source_keys if not TARGETS[key].is_file()]
    if missing:
        raise SystemExit(f"contact sheet inputs missing: {', '.join(missing)}")
    canvas = Image.new("RGB", SIZE, (8, 11, 16))
    draw = ImageDraw.Draw(canvas)
    title_font = _font(27)
    labels = (
        "A01 WORLD KEY ART",
        "A02 BASE VIEW",
        "A02 TOP VIEW",
        "A03 MATERIAL BIBLE",
    )
    positions = ((20, 72), (980, 72), (20, 576), (980, 576))
    draw.text((20, 18), "OVERHEAT COMBO — CELESTIAL FURNACE — R1-F1", font=_font(32), fill=(236, 240, 244))
    for key, label, (x, y) in zip(source_keys, labels, positions):
        draw.text((x, y), label, font=title_font, fill=(214, 184, 101))
        tile = _fit(_open_rgb(TARGETS[key]), (920, 450))
        canvas.paste(tile, (x, y + 36))
    TARGETS["contact"].parent.mkdir(parents=True, exist_ok=True)
    canvas.save(TARGETS["contact"], format="PNG", optimize=True)
    print(f"CONTACT SHEET: {TARGETS['contact']}")


def manifest() -> None:
    required = tuple(TARGETS)
    missing = [key for key in required if not TARGETS[key].is_file()]
    if missing:
        raise SystemExit(f"manifest inputs missing: {', '.join(missing)}")
    references = (
        ("current_structure_showcase", OUT / "reference" / "current_structure_showcase.png"),
        ("current_cast_showcase", OUT / "reference" / "current_cast_showcase.png"),
    )
    if any(not path.is_file() for _, path in references):
        raise SystemExit("reference screenshot missing")
    payload = {
        "schema_version": 1,
        "phase": "27K-R1-F1",
        "spec": SPEC,
        "spec_commit": SPEC_COMMIT,
        "runtime_import": False,
        "reference_policy": "project screenshots only; external reference images not stored or used as image inputs",
        "source_screenshots": [
            {"id": key, "path": path.relative_to(ROOT).as_posix(), "sha256": _sha256(path)}
            for key, path in references
        ],
        "artifacts": [
            {
                "id": key,
                "path": TARGETS[key].relative_to(ROOT).as_posix(),
                "width": SIZE[0],
                "height": SIZE[1],
                "sha256": _sha256(TARGETS[key]),
                "status": "candidate_for_user_review",
            }
            for key in required
        ],
    }
    target = OUT / "r1f1_manifest.json"
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"MANIFEST: {target}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Package and validate R1-F1 concept art.")
    sub = parser.add_subparsers(dest="command", required=True)
    normalize_parser = sub.add_parser("normalize")
    normalize_parser.add_argument("key", choices=("a01", "a02_base", "a02_top", "a03"))
    normalize_parser.add_argument("source", type=Path)
    validate_parser = sub.add_parser("validate")
    validate_parser.add_argument("keys", nargs="*", choices=tuple(TARGETS))
    validate_parser.add_argument("--all", action="store_true")
    sub.add_parser("contact-sheet")
    sub.add_parser("manifest")
    args = parser.parse_args()
    if args.command == "normalize":
        normalize(args.key, args.source)
        return 0
    if args.command == "validate":
        keys = list(TARGETS) if args.all else args.keys
        if not keys:
            parser.error("validate requires one or more keys, or --all")
        return validate(keys)
    if args.command == "contact-sheet":
        contact_sheet()
        return 0
    if args.command == "manifest":
        manifest()
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
