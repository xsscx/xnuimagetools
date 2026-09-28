# Copilot instructions

XNU Image Tools is a deterministic image and ICC quality-assurance generator.
The active codebase must not contain fuzzing, mutation, corruption, malformed
profile generation, fault injection, or automatic corpus commits.

## Behavioral contract

- Generate reproducible pixels and stable paths.
- Keep no-ICC and with-ICC outputs in separate directories.
- Never infer ICC presence from a filename, ColorSync display result, or `sips`
  metadata alone. Extract the container payload directly.
- Reject malformed ICC headers and mismatched source/profile hashes.
- Emit only format/profile combinations proven to preserve the ICC blob.
- Fail generation and CI when any requested file is absent or invalid.
- Keep the manifest and actual file set identical.

## Validation

Run the parser tests and full Catalyst generation command documented in
`README.md`. Generated images remain untracked artifacts. All generated text
must be ASCII.
