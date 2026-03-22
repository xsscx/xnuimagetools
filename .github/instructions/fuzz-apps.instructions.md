# fuzz-apps.sh — Path-Specific Instructions

## What This Is

A macOS shell script that feeds fuzzed images into 6 system image-parsing tools,
capturing exit codes, signals, and DiagnosticReports to identify crashes in Apple's
image decoding pipeline. Exercises the same code paths used by Preview, Mail, Notes,
Finder (QuickLook), and Spotlight.

## The 6 Tool Targets

| Tool | Command | Attack Surface |
|------|---------|---------------|
| sips --verify | `sips --debug --verify` | ImageIO / ColorSync validation |
| sips -g all | `sips -g all` | Metadata + ICC profile extraction |
| sips -s format | `sips -s format png --out` | Full decode → encode path |
| qlmanage -t | `qlmanage -t -s 128` | QuickLook thumbnail (Finder/Mail) |
| mdimport -t | `mdimport -t` | Spotlight metadata extraction |
| tiffutil -info | `tiffutil -info` | TIFF IFD parsing (TIFF only) |

## Usage

```bash
# Basic: fuzz all images in a directory
LATEST_RUN=$(ls -1dt fuzzed-images/*/ | sed -n '1p')
./fuzz-apps.sh "$LATEST_RUN" --timeout 15

# Extended timeout for complex/large images
./fuzz-apps.sh /tmp/fuzzed-output/pipeline-combo --timeout 30

# Specific tools only
FUZZ_APPS_TOOLS=sips-verify,qlmanage-t ./fuzz-apps.sh "$LATEST_RUN"

# Custom report directory
./fuzz-apps.sh "$LATEST_RUN" --report /tmp/my-report
```

`fuzz-apps.sh` expects a **directory** as its first argument, not a file glob.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| FUZZ_APPS_TIMEOUT | 15 | Per-tool timeout in seconds |
| FUZZ_APPS_REPORT | /tmp/fuzz-apps-report | Report output directory |
| FUZZ_APPS_TOOLS | all 6 tools | Comma-separated tool selection |

## Output

```
$REPORT_DIR/
├── findings.csv      # All results: file, tool, exit_code, signal, status
├── crashes/          # Copies of crash-triggering images
├── crash-logs/       # Copied DiagnosticReports .ips files
└── summary.txt       # Human-readable summary
```

## Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | All clean — no crashes |
| 2 | One or more crashes detected |
| 124 | Tool timeout (SIGKILL after timeout) |
| 128+ | Signal: 134=SIGABRT, 137=SIGKILL, 139=SIGSEGV |

## Integration with CFL Pipeline

Feed CFL fuzzer crash artifacts through fuzz-apps.sh to test macOS attack surface:
```bash
# Stage crash files in a directory, then point fuzz-apps.sh at that directory
CRASH_DIR=/tmp/cfl-crashes
./fuzz-apps.sh "$CRASH_DIR" --timeout 15

# Test xnuimagetools output
LATEST_RUN=$(ls -1dt fuzzed-images/*/ | sed -n '1p')
./fuzz-apps.sh "$LATEST_RUN"
```

## Adding New Tools

To add a new macOS image tool:
1. Add tool name to `ENABLED_TOOLS` default list
2. Add `tool_enabled` check in the main loop
3. Use `run_tool "$file" "tool-name" command args...`
4. The framework handles timeout, exit code classification, and CSV logging

## Potential Additions

Tools NOT yet included that exercise ICC/image code paths:
- `iccDumpProfile` / `iccToXml` — iccDEV tools (test ICC library directly)
- `iconutil` — icns parsing
- `cgpdftopdf` — PDF image extraction
- `afconvert` — Audio but exercises CoreAudio's image metadata path
