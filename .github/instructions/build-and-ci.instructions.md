---
applyTo: ".github/scripts/**,.github/workflows/**,contrib/scripts/**"
---

# Build and CI instructions

The decisive test is generation followed by direct container validation. Do
not use `|| true` around builds, generation, extraction, or validation. CI must
not rename fallback PNG data as another format and must not commit artifacts.
Keep validation dependency-free and add parser unit tests for new containers.
