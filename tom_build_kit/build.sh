#!/bin/bash
# Build script for BuildKit
#
# Compiles buildkit.dart to a native executable and installs it to ~/.tom/bin/
# Creates a 'bk' symlink for convenience.
#
# Usage:
#   ./build.sh           # Build for current platform
#   ./build.sh --help    # Show usage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect platform and architecture
case "$(uname -s)" in
    Darwin)
        case "$(uname -m)" in
            arm64) PLATFORM_DIR="darwin-arm64" ;;
            x86_64) PLATFORM_DIR="darwin-x64" ;;
            *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
        esac
        ;;
    Linux)
        case "$(uname -m)" in
            x86_64) PLATFORM_DIR="linux-x64" ;;
            aarch64) PLATFORM_DIR="linux-arm64" ;;
            *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported platform: $(uname -s)"
        exit 1
        ;;
esac

BIN_DIR="$HOME/.tom/bin/$PLATFORM_DIR"
BUILDKIT_PATH="$BIN_DIR/buildkit"
BK_LINK="$BIN_DIR/bk"

# Show help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "BuildKit Build Script"
    echo ""
    echo "Compiles buildkit.dart to a native executable and installs to:"
    echo "  $BIN_DIR/buildkit"
    echo ""
    echo "Also creates a 'bk' symlink for convenience."
    echo ""
    echo "Usage:"
    echo "  ./build.sh           Build and install"
    echo "  ./build.sh --help    Show this help"
    echo ""
    echo "Prerequisites:"
    echo "  - Dart SDK installed"
    echo "  - Run 'dart pub get' first if dependencies are missing"
    exit 0
fi

echo "╔══════════════════════════════════════════════════════╗"
echo "║              BuildKit Build Script                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Platform:    $PLATFORM_DIR"
echo "Target:      $BUILDKIT_PATH"
echo ""

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Check for pubspec.yaml and run pub get if needed
if [[ ! -d ".dart_tool" ]]; then
    echo "→ Running dart pub get..."
    dart pub get
    echo ""
fi

# Compile
echo "→ Compiling buildkit.dart..."
dart compile exe bin/buildkit.dart -o "$BUILDKIT_PATH"
echo ""

# Create symlink
if [[ -L "$BK_LINK" ]]; then
    rm "$BK_LINK"
fi
ln -s "$BUILDKIT_PATH" "$BK_LINK"
echo "→ Created symlink: bk → buildkit"
echo ""

# Verify
echo "╔══════════════════════════════════════════════════════╗"
echo "║                    Build Complete                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Installed:"
echo "  $BUILDKIT_PATH"
echo "  $BK_LINK → buildkit"
echo ""
echo "Make sure $BIN_DIR is in your PATH."
echo ""

# Show version
"$BUILDKIT_PATH" --version 2>/dev/null || true
