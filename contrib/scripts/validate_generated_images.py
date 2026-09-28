#!/usr/bin/env python3
"""Validate clean generated images and their exact ICC profile payloads."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path


MAGIC = {
    "png": b"\x89PNG\r\n\x1a\n",
    "jpg": b"\xff\xd8",
    "tiff": (b"II*\x00", b"MM\x00*"),
    "bmp": b"BM",
    "gif": (b"GIF87a", b"GIF89a"),
}


class ValidationError(ValueError):
    """Raised when generated output violates the manifest contract."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_icc(profile: bytes, label: str) -> None:
    if len(profile) < 132 or profile[36:40] != b"acsp":
        raise ValidationError(f"{label}: invalid ICC header")
    declared = int.from_bytes(profile[:4], "big")
    if declared != len(profile):
        raise ValidationError(f"{label}: invalid ICC declared size {declared}")
    tag_count = int.from_bytes(profile[128:132], "big")
    table_end = 132 + tag_count * 12
    if table_end > declared:
        raise ValidationError(f"{label}: ICC tag table exceeds profile size")
    for index in range(tag_count):
        entry = 132 + index * 12
        offset = int.from_bytes(profile[entry + 4 : entry + 8], "big")
        size = int.from_bytes(profile[entry + 8 : entry + 12], "big")
        if offset < table_end or size == 0 or offset + size > declared:
            raise ValidationError(f"{label}: invalid ICC tag {index}")


def png_profile(data: bytes) -> bytes | None:
    if not data.startswith(MAGIC["png"]):
        raise ValidationError("invalid PNG signature")
    offset = 8
    while offset + 12 <= len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        chunk_type = data[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValidationError("truncated PNG chunk")
        payload = data[offset + 8 : offset + 8 + length]
        if chunk_type == b"iCCP":
            separator = payload.find(b"\x00")
            if separator < 1 or separator + 2 > len(payload) or payload[separator + 1] != 0:
                raise ValidationError("invalid PNG iCCP chunk")
            try:
                return zlib.decompress(payload[separator + 2 :])
            except zlib.error as error:
                raise ValidationError(f"invalid PNG iCCP compression: {error}") from error
        offset = end
        if chunk_type == b"IEND":
            break
    return None


def jpeg_profile(data: bytes) -> bytes | None:
    if not data.startswith(MAGIC["jpg"]):
        raise ValidationError("invalid JPEG signature")
    offset = 2
    parts: dict[int, bytes] = {}
    expected_count = 0
    while offset < len(data):
        if data[offset] != 0xFF:
            raise ValidationError("invalid JPEG marker stream")
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            break
        marker = data[offset]
        offset += 1
        if marker in (0xD9, 0xDA):
            break
        if marker == 0x01 or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(data):
            raise ValidationError("truncated JPEG segment")
        length = int.from_bytes(data[offset : offset + 2], "big")
        if length < 2 or offset + length > len(data):
            raise ValidationError("invalid JPEG segment length")
        payload = data[offset + 2 : offset + length]
        if marker == 0xE2 and payload.startswith(b"ICC_PROFILE\x00"):
            if len(payload) < 14:
                raise ValidationError("truncated JPEG ICC segment")
            sequence, count = payload[12], payload[13]
            if not sequence or not count or sequence > count:
                raise ValidationError("invalid JPEG ICC sequence")
            if expected_count and expected_count != count:
                raise ValidationError("inconsistent JPEG ICC segment count")
            expected_count = count
            if sequence in parts:
                raise ValidationError("duplicate JPEG ICC segment")
            parts[sequence] = payload[14:]
        offset += length
    if not parts:
        return None
    if set(parts) != set(range(1, expected_count + 1)):
        raise ValidationError("incomplete JPEG ICC profile")
    return b"".join(parts[index] for index in range(1, expected_count + 1))


def tiff_fields(data: bytes) -> tuple[str, dict[int, tuple[int, int, bytes]]]:
    if data.startswith(b"II*\x00"):
        endian = "<"
    elif data.startswith(b"MM\x00*"):
        endian = ">"
    else:
        raise ValidationError("invalid TIFF signature")
    if len(data) < 8:
        raise ValidationError("truncated TIFF header")
    ifd_offset = struct.unpack_from(endian + "I", data, 4)[0]
    if ifd_offset + 2 > len(data):
        raise ValidationError("invalid TIFF IFD offset")
    count = struct.unpack_from(endian + "H", data, ifd_offset)[0]
    fields: dict[int, tuple[int, int, bytes]] = {}
    for index in range(count):
        entry = ifd_offset + 2 + index * 12
        if entry + 12 > len(data):
            raise ValidationError("truncated TIFF IFD")
        tag, field_type, value_count = struct.unpack_from(endian + "HHI", data, entry)
        fields[tag] = (field_type, value_count, data[entry + 8 : entry + 12])
    return endian, fields


def tiff_value(data: bytes, endian: str, field: tuple[int, int, bytes]) -> bytes:
    field_type, count, inline = field
    sizes = {1: 1, 3: 2, 4: 4, 7: 1}
    if field_type not in sizes:
        raise ValidationError(f"unsupported TIFF field type {field_type}")
    size = sizes[field_type] * count
    if size <= 4:
        return inline[:size]
    offset = struct.unpack(endian + "I", inline)[0]
    if offset + size > len(data):
        raise ValidationError("invalid TIFF field offset")
    return data[offset : offset + size]


def tiff_profile(data: bytes) -> bytes | None:
    endian, fields = tiff_fields(data)
    field = fields.get(34675)
    return None if field is None else tiff_value(data, endian, field)


def bmp_profile(data: bytes) -> bytes | None:
    if not data.startswith(MAGIC["bmp"]) or len(data) < 18:
        raise ValidationError("invalid BMP signature")
    dib_size = int.from_bytes(data[14:18], "little")
    if dib_size < 124 or len(data) < 14 + 120:
        return None
    color_space_type = int.from_bytes(data[14 + 56 : 14 + 60], "little")
    if color_space_type != 0x4D424544:
        return None
    offset = int.from_bytes(data[14 + 112 : 14 + 116], "little")
    size = int.from_bytes(data[14 + 116 : 14 + 120], "little")
    start = 14 + offset
    if not size or start + size > len(data):
        raise ValidationError("invalid BMP embedded profile")
    return data[start : start + size]


def gif_profile(data: bytes) -> bytes | None:
    if not data.startswith(MAGIC["gif"]):
        raise ValidationError("invalid GIF signature")
    marker = data.find(b"\x21\xff\x0bICCRGBG1012")
    if marker < 0:
        return None
    offset = marker + 14
    parts = []
    while offset < len(data):
        size = data[offset]
        offset += 1
        if size == 0:
            return b"".join(parts)
        if offset + size > len(data):
            raise ValidationError("truncated GIF ICC extension")
        parts.append(data[offset : offset + size])
        offset += size
    raise ValidationError("unterminated GIF ICC extension")


def extract_profile(data: bytes, extension: str) -> bytes | None:
    extractors = {
        "png": png_profile,
        "jpg": jpeg_profile,
        "tiff": tiff_profile,
        "bmp": bmp_profile,
        "gif": gif_profile,
    }
    return extractors[extension](data)


def image_dimensions(data: bytes, extension: str) -> tuple[int, int]:
    if extension == "png":
        return struct.unpack(">II", data[16:24])
    if extension == "gif":
        return struct.unpack("<HH", data[6:10])
    if extension == "bmp":
        width, height = struct.unpack("<ii", data[18:26])
        return abs(width), abs(height)
    if extension == "tiff":
        endian, fields = tiff_fields(data)
        values = []
        for tag in (256, 257):
            raw = tiff_value(data, endian, fields[tag])
            values.append(int.from_bytes(raw, "little" if endian == "<" else "big"))
        return values[0], values[1]
    if extension == "jpg":
        offset = 2
        while offset + 4 <= len(data):
            while offset < len(data) and data[offset] == 0xFF:
                offset += 1
            marker = data[offset]
            offset += 1
            if marker in (0xD9, 0xDA):
                break
            length = int.from_bytes(data[offset : offset + 2], "big")
            if marker in range(0xC0, 0xD0) and marker not in (0xC4, 0xC8, 0xCC):
                height, width = struct.unpack(">HH", data[offset + 3 : offset + 7])
                return width, height
            offset += length
    raise ValidationError(f"cannot read {extension} dimensions")


def check_magic(data: bytes, extension: str) -> None:
    signatures = MAGIC[extension]
    if isinstance(signatures, tuple):
        valid = any(data.startswith(signature) for signature in signatures)
    else:
        valid = data.startswith(signatures)
    if not valid:
        raise ValidationError(f"content does not match .{extension} extension")


def validate_directory(root: Path) -> int:
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        raise ValidationError(f"missing manifest: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="ascii"))
    if manifest.get("schemaVersion") != 1:
        raise ValidationError("unsupported manifest schema")
    entries = manifest.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValidationError("manifest has no entries")

    declared_paths = set()
    mode_counts = {"none": 0, "with": 0}
    for entry in entries:
        relative = entry["path"]
        if relative in declared_paths or Path(relative).is_absolute() or ".." in Path(relative).parts:
            raise ValidationError(f"unsafe or duplicate manifest path: {relative}")
        declared_paths.add(relative)
        path = root / relative
        if not path.is_file():
            raise ValidationError(f"missing output: {relative}")
        data = path.read_bytes()
        extension = entry["format"]
        if path.suffix.lower().lstrip(".") != extension:
            raise ValidationError(f"extension mismatch: {relative}")
        check_magic(data, extension)
        if sha256(data) != entry["fileSHA256"]:
            raise ValidationError(f"file hash mismatch: {relative}")
        if image_dimensions(data, extension) != (entry["width"], entry["height"]):
            raise ValidationError(f"dimension mismatch: {relative}")

        profile = extract_profile(data, extension)
        mode = entry["iccMode"]
        if mode not in mode_counts:
            raise ValidationError(f"invalid ICC mode in manifest: {mode}")
        mode_counts[mode] += 1
        if mode == "none":
            if profile is not None:
                raise ValidationError(f"unexpected ICC profile: {relative}")
            if entry.get("iccProfile") is not None or entry.get("sourceICCSHA256") is not None:
                raise ValidationError(f"unprofiled manifest metadata mismatch: {relative}")
        elif mode == "with":
            if profile is None:
                raise ValidationError(f"missing ICC profile: {relative}")
            validate_icc(profile, relative)
            if sha256(profile) != entry.get("sourceICCSHA256"):
                raise ValidationError(f"ICC profile hash mismatch: {relative}")
            if not entry.get("iccProfile"):
                raise ValidationError(f"missing ICC profile name: {relative}")

    actual_paths = {
        str(path.relative_to(root))
        for path in root.rglob("*")
        if path.is_file() and path.name != "manifest.json"
    }
    if actual_paths != declared_paths:
        extra = sorted(actual_paths - declared_paths)
        missing = sorted(declared_paths - actual_paths)
        raise ValidationError(f"manifest/file set mismatch; extra={extra}, missing={missing}")

    requested = manifest.get("requestedICCMode")
    if requested not in ("none", "with", "both"):
        raise ValidationError(f"invalid requested ICC mode: {requested}")
    if requested in ("none", "both") and mode_counts["none"] == 0:
        raise ValidationError("requested unprofiled output is absent")
    if requested in ("with", "both") and mode_counts["with"] == 0:
        raise ValidationError("requested profiled output is absent")
    if requested == "none" and mode_counts["with"]:
        raise ValidationError("profiled output present in none mode")
    if requested == "with" and mode_counts["none"]:
        raise ValidationError("unprofiled output present in with mode")

    print(
        f"PASS: {len(entries)} images; "
        f"no-icc={mode_counts['none']}; with-icc={mode_counts['with']}"
    )
    return len(entries)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path, help="generated output directory")
    args = parser.parse_args()
    try:
        validate_directory(args.output.resolve())
    except (OSError, KeyError, TypeError, json.JSONDecodeError, ValidationError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
