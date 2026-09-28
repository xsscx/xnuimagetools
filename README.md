# XNU Image Tools

XNU Image Tools generates deterministic, standards-compliant image corpora for
Apple image and color-management quality assurance. The active repository does
not mutate files, corrupt containers, alter ICC bytes, or run fuzzing campaigns.

The iOS application is also the Mac Catalyst command runner. It creates a
manifested corpus in one of three explicit modes:

- `none`: PNG, JPEG, TIFF, BMP, and GIF with no embedded ICC profile.
- `with`: valid ICC-bearing files only.
- `both`: both sets; this is the default.

## Generate and validate locally

macOS with Xcode is required. No third-party Python packages are needed.

```sh
.github/scripts/generate-clean-images.sh generated-images both
```

The script builds the Release Mac Catalyst app, runs it, waits for
`manifest.json`, and invokes the fail-closed validator. Use `none` or `with` as
the second argument to generate only one side of the QA matrix.

The application honors these environment variables when run directly:

- `XNU_IMAGE_OUTPUT_DIR`: output directory.
- `XNU_IMAGE_ICC_MODE`: `none`, `with`, or `both`.

Output is deterministic and separated into `no-icc/` and `with-icc/`. Generated
corpora are artifacts and are intentionally ignored by Git.

## ICC compatibility contract

ImageIO does not preserve every named RGB ICC blob in every container. The
generator emits only combinations verified to retain the exact source profile:

| Profile | PNG | JPEG | TIFF |
| --- | --- | --- | --- |
| Display P3 | yes | yes | yes |
| Adobe RGB (1998) | no | yes | yes |
| sRGB | no | no | yes |

For excluded combinations, ImageIO may replace the blob with a container-native
color marker or a canonicalized profile. Such files are not labeled as ICC test
cases here. The validator extracts PNG `iCCP`, JPEG APP2, and TIFF tag 34675
payloads directly and compares their SHA-256 hashes with the source profile.
BMP V5 and GIF ICC extensions are also inspected to prove the no-profile set is
actually unprofiled.

## Projects

- `XNU Image Generator for iOS`: canonical iOS/iPadOS and Mac Catalyst generator.
- `XNU Image Generator for Watch`: deterministic, unprofiled watchOS generator.
- `XNU Image Tools.xcworkspace`: opens both maintained projects.
- `contrib/scripts/validate_generated_images.py`: dependency-free validator.

## Tests

```sh
python3 -m unittest contrib/scripts/test_validate_generated_images.py
xcodebuild build \
  -project 'XNU Image Generator for iOS/XNU Image Generator for iOS.xcodeproj' \
  -scheme 'XNU Image Generator for iOS' \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project 'XNU Image Generator for Watch/XNU Image Generator.xcodeproj' \
  -scheme 'XNU Image Generator Watch App' \
  -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

CI uploads generated corpora for manual QA. It never commits generated images
back to the repository.

See `docs/DEVICE_QA.md` for the iPhone and iPad handoff procedure.
