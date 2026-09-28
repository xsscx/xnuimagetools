# Validation tooling

`scripts/validate_generated_images.py` validates a generated corpus without
third-party Python packages. It checks the manifest, file hashes, dimensions,
container signatures, and ICC payloads. PNG `iCCP`, JPEG APP2, TIFF tag 34675,
BMP V5, and GIF ICC application data are inspected directly.

Run the parser unit tests with:

```sh
python3 -m unittest contrib/scripts/test_validate_generated_images.py
```

Run full generation and validation with:

```sh
.github/scripts/generate-clean-images.sh generated-images both
```
