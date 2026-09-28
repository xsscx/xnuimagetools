---
applyTo: "XNU Image Generator for iOS/**/*.swift,XNU Image Generator for Watch/**/*.swift"
---

# Generator source instructions

Rendering must be deterministic. Do not use random values, mutate encoded
bytes, or silently save an unprofiled image after an ICC operation fails.
Profiled output requires a valid `acsp` header, a successful color-space copy,
and a container/profile combination covered by the compatibility matrix.
