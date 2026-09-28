#!/usr/bin/env python3
"""Unit tests for direct ICC container extraction."""

import importlib.util
import hashlib
import json
import struct
import tempfile
import unittest
import zlib
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("validate_generated_images.py")
SPEC = importlib.util.spec_from_file_location("validator", MODULE_PATH)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def profile() -> bytes:
    data = bytearray(132)
    data[:4] = (132).to_bytes(4, "big")
    data[36:40] = b"acsp"
    return bytes(data)


class ExtractProfileTests(unittest.TestCase):
    def test_png_iccp(self) -> None:
        payload = b"sRGB\x00\x00" + zlib.compress(profile())
        chunk = struct.pack(">I", len(payload)) + b"iCCP" + payload + b"\x00\x00\x00\x00"
        image = validator.MAGIC["png"] + chunk
        self.assertEqual(validator.png_profile(image), profile())

    def test_jpeg_app2(self) -> None:
        payload = b"ICC_PROFILE\x00\x01\x01" + profile()
        image = b"\xff\xd8\xff\xe2" + struct.pack(">H", len(payload) + 2) + payload + b"\xff\xd9"
        self.assertEqual(validator.jpeg_profile(image), profile())

    def test_tiff_icc_tag(self) -> None:
        profile_offset = 8 + 2 + 12 + 4
        entry = struct.pack("<HHII", 34675, 7, len(profile()), profile_offset)
        image = b"II*\x00" + struct.pack("<I", 8) + struct.pack("<H", 1) + entry + b"\x00\x00\x00\x00" + profile()
        self.assertEqual(validator.tiff_profile(image), profile())

    def test_rejects_bad_icc_header(self) -> None:
        with self.assertRaises(validator.ValidationError):
            validator.validate_icc(bytes(128), "bad")

    def test_manifest_rejects_missing_profile(self) -> None:
        ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
        chunk = struct.pack(">I", len(ihdr)) + b"IHDR" + ihdr + b"\x00\x00\x00\x00"
        image = validator.MAGIC["png"] + chunk
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "with-icc" / "srgb" / "sample.png"
            path.parent.mkdir(parents=True)
            path.write_bytes(image)
            manifest = {
                "schemaVersion": 1,
                "requestedICCMode": "with",
                "entries": [{
                    "path": "with-icc/srgb/sample.png",
                    "format": "png",
                    "width": 1,
                    "height": 1,
                    "iccMode": "with",
                    "iccProfile": "srgb",
                    "sourceICCSHA256": "0" * 64,
                    "fileSHA256": hashlib.sha256(image).hexdigest(),
                }],
            }
            (root / "manifest.json").write_text(json.dumps(manifest), encoding="ascii")
            with self.assertRaisesRegex(validator.ValidationError, "missing ICC profile"):
                validator.validate_directory(root)


if __name__ == "__main__":
    unittest.main()
