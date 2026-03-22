#!/usr/bin/env python3
"""Validate fuzzed images for embedded injection strings.

Scans image outputs for embedded marker strings in LSB/MSB bit planes,
highlights detected regions, and writes a plain-text report for CI summaries.

Usage:
    python3 validate_fuzzed_images.py [image_dir] [output_dir]
    python3 validate_fuzzed_images.py --input IMAGE_DIR --output OUTPUT_DIR

Defaults:
    image_dir:  current directory
    output_dir: image_dir/compare/
    report:     output_dir/report.txt
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


SUPPORTED_EXTENSIONS = (".png", ".jpg", ".jpeg", ".gif", ".tiff", ".tif", ".bmp")

# Injection strings
INJECT_STRINGS = [
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    "<script>console.error('XNU Image Fuzzer');</script>",
    "' OR ''='",
    "%d %s %d %s",
    "XNU Image Fuzzer",
    "123456; DROP TABLE users",
    "!@#$%^&*()_+=",
    "..//..//..//win",
    "\0\0\0",
    '<?xml version="1.0"?><!DOCTYPE replace [<!ENTITY example "XNUImageFuzzer"> ]><userInfo><firstName>XNUImageFuzzer<&example;></firstName></userInfo>',
]

INJECTION_PATTERNS = [(text, text.encode("utf-8")) for text in INJECT_STRINGS]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate fuzzed images for embedded marker strings."
    )
    parser.add_argument(
        "image_dir",
        nargs="?",
        help="Directory containing images to scan (legacy positional form).",
    )
    parser.add_argument(
        "output_dir",
        nargs="?",
        help="Directory to write validation artifacts (legacy positional form).",
    )
    parser.add_argument(
        "--input",
        dest="input_dir_flag",
        help="Directory containing images to scan.",
    )
    parser.add_argument(
        "--output",
        dest="output_dir_flag",
        help="Directory to write validation artifacts.",
    )
    parser.add_argument(
        "--report",
        dest="report_path",
        help="Optional explicit path for the text summary report.",
    )
    return parser.parse_args()


def resolve_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    image_dir = Path(args.input_dir_flag or args.image_dir or ".")
    output_dir = Path(args.output_dir_flag or args.output_dir or image_dir / "compare")
    report_path = Path(args.report_path) if args.report_path else output_dir / "report.txt"
    return image_dir, output_dir, report_path


def iter_candidate_files(image_dir: Path) -> Iterable[Path]:
    for path in sorted(image_dir.iterdir()):
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
            yield path


def sanitize_match(match: str) -> str:
    escaped = match.encode("unicode_escape").decode("ascii")
    if len(escaped) > 80:
        return escaped[:77] + "..."
    return escaped


def extract_payload_from_image(image_path: Path, bit_position: str = "LSB") -> tuple[bytes, Image.Image]:
    with Image.open(image_path) as source:
        source.load()
        image = source.convert("RGB")

    payload = bytearray()
    current_byte = 0
    bit_count = 0

    for value in image.tobytes():
        if bit_position == "LSB":
            bit = value & 1
        elif bit_position == "MSB":
            bit = (value >> 7) & 1
        else:
            raise ValueError(f"Unsupported bit position: {bit_position}")

        current_byte = (current_byte << 1) | bit
        bit_count += 1
        if bit_count == 8:
            payload.append(current_byte)
            current_byte = 0
            bit_count = 0

    return bytes(payload), image


def check_injection_strings(payload: bytes) -> tuple[str | None, int]:
    for inject_string, pattern in INJECTION_PATTERNS:
        index = payload.find(pattern)
        if index != -1:
            return inject_string, index * 8
    return None, -1


def visualize_encoded_data(image: Image.Image, start_bit: int, bit_length: int) -> Image.Image:
    draw = ImageDraw.Draw(image)
    highlight_color = (255, 0, 0)

    for bit_index in range(start_bit, start_bit + bit_length):
        pixel_index = bit_index // 3
        x = pixel_index % image.width
        y = pixel_index // image.width
        if y >= image.height:
            break
        draw.point((x, y), fill=highlight_color)

    return image


def create_filmstrip(
    original_image: Image.Image,
    highlighted_image: Image.Image,
    bit_position: str,
    image_name: str,
    output_dir: Path,
) -> None:
    width, height = original_image.size
    filmstrip = Image.new("RGB", (width * 2, height))
    filmstrip.paste(original_image, (0, 0))
    filmstrip.paste(highlighted_image, (width, 0))

    draw = ImageDraw.Draw(filmstrip)
    draw.text((10, 10), "Original", fill=(255, 255, 255))
    draw.text((width + 10, 10), f"Highlighted ({bit_position})", fill=(255, 255, 255))

    filmstrip.save(output_dir / f"filmstrip_{bit_position}_{image_name}")


def verify_and_visualize_images(image_dir: Path, output_dir: Path, bit_position: str) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)

    result = {
        "bit_position": bit_position,
        "scanned": 0,
        "skipped": 0,
        "injections_found": 0,
        "decode_failures": [],
        "detections": [],
    }

    for image_path in iter_candidate_files(image_dir):
        try:
            payload, original_image = extract_payload_from_image(image_path, bit_position)
        except Exception as exc:  # pragma: no cover - exercised by malformed corpora
            result["skipped"] += 1
            result["decode_failures"].append(f"{image_path.name}: {type(exc).__name__}")
            continue

        result["scanned"] += 1
        found_string, start_bit = check_injection_strings(payload)
        if not found_string:
            continue

        result["injections_found"] += 1
        sanitized = sanitize_match(found_string)
        result["detections"].append(
            {
                "file": image_path.name,
                "match": sanitized,
                "start_bit": start_bit,
            }
        )

        bit_length = len(found_string.encode("utf-8")) * 8
        highlighted = visualize_encoded_data(Image.new("RGB", original_image.size), start_bit, bit_length)
        highlighted.save(output_dir / f"highlighted_{bit_position}_{image_path.name}")
        create_filmstrip(original_image, highlighted, bit_position, image_path.name, output_dir)
        print(f"  FOUND in {image_path.name}: {sanitized}")

    print(
        f"  {bit_position}: scanned={result['scanned']}, "
        f"skipped={result['skipped']}, injections_found={result['injections_found']}"
    )
    return result


def write_report(report_path: Path, image_dir: Path, output_dir: Path, results: list[dict]) -> None:
    lines = [
        "Validation Report",
        f"Input directory: {image_dir}",
        f"Output directory: {output_dir}",
        f"Supported extensions: {', '.join(SUPPORTED_EXTENSIONS)}",
        "",
    ]

    for result in results:
        lines.append(
            f"{result['bit_position']}: scanned={result['scanned']}, "
            f"skipped={result['skipped']}, injections_found={result['injections_found']}"
        )
        if result["detections"]:
            lines.append("Detections:")
            for detection in result["detections"]:
                lines.append(
                    f"- {detection['file']}: {detection['match']} "
                    f"(start_bit={detection['start_bit']})"
                )
        if result["decode_failures"]:
            lines.append("Decode failures:")
            for failure in result["decode_failures"]:
                lines.append(f"- {failure}")
        lines.append("")

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    image_dir, output_dir, report_path = resolve_paths(args)

    print(f"Validating images in: {image_dir}")
    print(f"Output directory: {output_dir}")
    print(f"Report path: {report_path}")

    if not image_dir.is_dir():
        raise SystemExit(f"Input directory does not exist: {image_dir}")

    results = [
        verify_and_visualize_images(image_dir, output_dir, bit_position="LSB"),
        verify_and_visualize_images(image_dir, output_dir, bit_position="MSB"),
    ]
    write_report(report_path, image_dir, output_dir, results)
    print(f"Wrote report: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
