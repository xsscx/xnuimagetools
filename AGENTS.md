# Repository agent instructions

This repository is a deterministic image generator, not a fuzzing project.

- Do not add mutation, corruption, fault injection, malformed ICC profiles, or
  generated corpora to the active tree.
- Treat an ICC-labeled output as valid only after direct container extraction
  proves that a compliant ICC blob is present.
- Keep no-ICC output separate and prove that no profile payload exists.
- Preserve deterministic pixels, stable filenames, a complete manifest, and
  fail-closed validation.
- Do not add third-party runtime dependencies without a demonstrated need.
- CI may upload generated artifacts but must never auto-commit them.
- Keep generated text ASCII.

Run before committing:

```sh
python3 -m unittest contrib/scripts/test_validate_generated_images.py
.github/scripts/generate-clean-images.sh generated-images both
```
