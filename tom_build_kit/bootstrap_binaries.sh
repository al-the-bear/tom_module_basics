#!/bin/bash
# Bootstrap script for tom_build_kit binaries
# Run this to compile all buildkit tools to native binaries
#
# Usage:
#   ./bootstrap_binaries.sh [platform]
#
# Platform defaults to auto-detected value. Override for cross-compilation:
#   ./bootstrap_binaries.sh darwin-arm64
#   ./bootstrap_binaries.sh linux-x64

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Find tom_binaries directory (walk up from script dir to tom_agent_container)
TOM_BINARIES_ROOT="$SCRIPT_DIR"
while [[ "$TOM_BINARIES_ROOT" != "/" ]]; do
    if [[ -d "$TOM_BINARIES_ROOT/tom_binaries" ]]; then
        break
    fi
    TOM_BINARIES_ROOT="$(dirname "$TOM_BINARIES_ROOT")"
done

if [[ ! -d "$TOM_BINARIES_ROOT/tom_binaries" ]]; then
    echo "Error: Could not find tom_binaries directory"
    exit 1
fi

# Determine platform (auto-detect or use argument)
if [[ -n "$1" ]]; then
    PLATFORM="$1"
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
            PLATFORM="darwin-arm64"
        else
            PLATFORM="darwin-x64"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ "$(uname -m)" == "aarch64" ]]; then
            PLATFORM="linux-arm64"
        else
            PLATFORM="linux-x64"
        fi
    else
        echo "Unsupported platform: $OSTYPE (pass platform as argument)"
        exit 1
    fi
fi

OUTPUT_DIR="$TOM_BINARIES_ROOT/tom_binaries/tom/$PLATFORM"
mkdir -p "$OUTPUT_DIR"

echo "=== Bootstrap tom_build_kit binaries ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

# Step 1: Create stub version.versioner.dart if missing
if [[ ! -f lib/src/version.versioner.dart ]]; then
    echo "Creating stub version.versioner.dart..."
    cat > lib/src/version.versioner.dart << 'EOF'
// GENERATED FILE - DO NOT EDIT
// Bootstrap stub - will be regenerated

class BuildkitVersionInfo {
  BuildkitVersionInfo._();
  static const String version = '0.0.0';
  static const String buildTime = '1970-01-01T00:00:00.000000Z';
  static const String gitCommit = 'bootstrap';
  static const int buildNumber = 0;
  static const String dartSdkVersion = 'unknown';
  static String get versionShort => '$version+$buildNumber';
  static String get versionMedium => '$version+$buildNumber.$gitCommit ($buildTime)';
  static String get versionLong => '$version+$buildNumber.$gitCommit ($buildTime) [Dart $dartSdkVersion]';
}
EOF
fi

# Step 2: Run versioner to generate proper version file
echo "Running versioner..."
dart run bin/buildkit.dart --scan . --no-recursive :versioner --variable-prefix buildkit
echo ""

# Step 3: Define tools to compile
# Only standalone entry points live in bin/ — all other tools
# (versioner, compiler, cleanup, git*, etc.) are sub-commands of buildkit.
TOOLS=(
    buildkit
    findproject
)

# Step 4: Compile each tool
echo "Compiling tools to $OUTPUT_DIR..."
for tool in "${TOOLS[@]}"; do
    if [[ ! -f "bin/$tool.dart" ]]; then
        echo "    Warning: bin/$tool.dart not found, skipping"
        continue
    fi
    echo "  Compiling $tool..."
    dart compile exe "bin/$tool.dart" -o "$OUTPUT_DIR/$tool" 2>/dev/null || {
        echo "    Warning: Failed to compile $tool"
    }
done

echo ""
echo "=== Bootstrap complete ==="
echo "Compiled ${#TOOLS[@]} tools to $OUTPUT_DIR"
echo ""
echo "Add to PATH:"
echo "  export PATH=\"\$PATH:$OUTPUT_DIR\""
