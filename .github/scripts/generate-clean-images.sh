#!/bin/bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/../.." && pwd)
output_dir=${1:-"$repo_dir/generated-images"}
icc_mode=${2:-both}
derived_data=${XNU_IMAGE_DERIVED_DATA:-"$repo_dir/DerivedData"}
project="$repo_dir/XNU Image Generator for iOS/XNU Image Generator for iOS.xcodeproj"
scheme="XNU Image Generator for iOS"

case "$icc_mode" in
    none|with|both) ;;
    *)
        echo "usage: $0 [output-directory] [none|with|both]" >&2
        exit 2
        ;;
esac

xcodebuild build \
    -project "$project" \
    -scheme "$scheme" \
    -configuration Release \
    -destination "platform=macOS,variant=Mac Catalyst" \
    -derivedDataPath "$derived_data" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

app="$derived_data/Build/Products/Release-maccatalyst/XNU Image Generator for iOS.app"
binary="$app/Contents/MacOS/XNU Image Generator for iOS"
if [[ ! -x "$binary" ]]; then
    echo "generator executable not found: $binary" >&2
    exit 1
fi

mkdir -p "$output_dir"
log_file="$output_dir/generator.log"
rm -f "$output_dir/manifest.json"
XNU_IMAGE_OUTPUT_DIR="$output_dir" XNU_IMAGE_ICC_MODE="$icc_mode" \
    "$binary" >"$log_file" 2>&1 &
generator_pid=$!

cleanup() {
    if kill -0 "$generator_pid" 2>/dev/null; then
        kill "$generator_pid" 2>/dev/null || true
        wait "$generator_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

for _ in $(seq 1 240); do
    if [[ -f "$output_dir/manifest.json" ]]; then
        break
    fi
    if ! kill -0 "$generator_pid" 2>/dev/null; then
        echo "generator exited before writing manifest" >&2
        sed -n '1,200p' "$log_file" >&2
        exit 1
    fi
    sleep 0.25
done

if [[ ! -f "$output_dir/manifest.json" ]]; then
    echo "generator timed out before writing manifest" >&2
    sed -n '1,200p' "$log_file" >&2
    exit 1
fi

cleanup
trap - EXIT
rm -f "$log_file"
python3 "$repo_dir/contrib/scripts/validate_generated_images.py" "$output_dir"
