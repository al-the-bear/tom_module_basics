#!/bin/bash
# Bootstrap script for tom_build_kit binaries
# Run this to compile all buildkit tools to native binaries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Determine output directory based on platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        OUTPUT_DIR="$HOME/.tom/bin/darwin-arm64"
    else
        OUTPUT_DIR="$HOME/.tom/bin/darwin-x64"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OUTPUT_DIR="$HOME/.tom/bin/linux-x64"
else
    echo "Unsupported platform: $OSTYPE"
    exit 1
fi

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
dart run bin/versioner.dart --variable-prefix buildkit
echo ""

# Step 3: Define tools to compile
TOOLS=(
    buildkit
    versioner
    compiler
    cleanup
    runner
    dependencies
    bumpversion
    buildsorter
    publisher
    goto
    # Git tools
    git
    gitbranch
    gitcheckout
    gitclean
    gitcommit
    gitcompare
    gitmerge
    gitprune
    gitpull
    gitrebase
    gitreset
    gitsquash
    gitstash
    gitstatus
    gitsync
    gittag
    gitunstash
)

# Step 4: Compile each tool
echo "Compiling tools to $OUTPUT_DIR..."
for tool in "${TOOLS[@]}"; do
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
