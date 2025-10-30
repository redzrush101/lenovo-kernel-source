#!/bin/bash
# AOSP Toolchain Setup for MT6765 Kernel (4.9.117)
# Downloads Clang and GCC from AOSP prebuilts
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_DIR="$(dirname "$SCRIPT_DIR")/toolchains"

echo "================================================="
echo "AOSP Toolchain Setup for Android Kernel"
echo "================================================="
echo "Installation directory: $TOOLCHAIN_DIR"
echo ""

# Detect existing toolchains
check_existing() {
    local name="$1"
    local path="$2"
    if [ -d "$path" ]; then
        echo "[EXISTS] $name at $path"
        return 0
    fi
    return 1
}

# Download and extract tarball
download_toolchain() {
    local name="$1"
    local url="$2"
    local dest_dir="$3"
    
    echo "[DOWNLOAD] $name"
    echo "  URL: $url"
    
    local tarball="/tmp/$(basename "$url")"
    
    # Download
    if [ ! -f "$tarball" ]; then
        wget -q --show-progress "$url" -O "$tarball" || {
            echo "[ERROR] Failed to download $name"
            return 1
        }
    else
        echo "  [CACHED] Using existing tarball: $tarball"
    fi
    
    # Extract
    echo "  [EXTRACT] To $dest_dir"
    mkdir -p "$dest_dir"
    tar -xf "$tarball" -C "$dest_dir" || {
        echo "[ERROR] Failed to extract $name"
        rm -f "$tarball"
        return 1
    }
    
    # Cleanup
    rm -f "$tarball"
    echo "  [OK] $name installed"
}

# Create toolchain directory
mkdir -p "$TOOLCHAIN_DIR"

echo ""
echo "Step 1/3: Clang Toolchain"
echo "================================================="

# For 4.9.117 (Pie era), use clang-4691093 (Clang 5.0)
# This matches what Lenovo originally used
CLANG_VERSION="clang-4691093"
CLANG_DIR="$TOOLCHAIN_DIR/$CLANG_VERSION"

if check_existing "Clang $CLANG_VERSION" "$CLANG_DIR"; then
    echo "  Skipping download"
else
    CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/android-9.0.0_r1/${CLANG_VERSION}.tar.gz"
    download_toolchain "Clang $CLANG_VERSION" "$CLANG_URL" "$CLANG_DIR"
fi

# Verify Clang
if [ -x "$CLANG_DIR/bin/clang" ]; then
    CLANG_VER=$("$CLANG_DIR/bin/clang" --version | head -1)
    echo "[VERIFY] $CLANG_VER"
else
    echo "[ERROR] Clang binary not found at $CLANG_DIR/bin/clang"
    exit 1
fi

echo ""
echo "Step 2/3: GCC ARM64 Toolchain"
echo "================================================="

# GCC 4.9 for aarch64 (matches original script)
GCC_ARM64_VERSION="aarch64-linux-android-4.9"
GCC_ARM64_DIR="$TOOLCHAIN_DIR/gcc-arm64"

if check_existing "GCC ARM64" "$GCC_ARM64_DIR"; then
    echo "  Skipping download"
else
    # Clone from AOSP (this is smaller than full repo)
    echo "[DOWNLOAD] GCC ARM64 from AOSP"
    git clone --depth=1 -b android-9.0.0_r1 \
        https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/${GCC_ARM64_VERSION} \
        "$GCC_ARM64_DIR" || {
        echo "[ERROR] Failed to clone GCC ARM64"
        exit 1
    }
    # Remove git history to save space
    rm -rf "$GCC_ARM64_DIR/.git"
    echo "  [OK] GCC ARM64 installed"
fi

# Verify GCC ARM64
if [ -x "$GCC_ARM64_DIR/bin/aarch64-linux-android-gcc" ]; then
    GCC64_VER=$("$GCC_ARM64_DIR/bin/aarch64-linux-android-gcc" --version | head -1)
    echo "[VERIFY] $GCC64_VER"
else
    echo "[ERROR] GCC ARM64 binary not found"
    exit 1
fi

echo ""
echo "Step 3/3: GCC ARM32 Toolchain"
echo "================================================="

# GCC 4.9 for arm (for compat vDSO)
GCC_ARM32_VERSION="arm-linux-androideabi-4.9"
GCC_ARM32_DIR="$TOOLCHAIN_DIR/gcc-arm32"

if check_existing "GCC ARM32" "$GCC_ARM32_DIR"; then
    echo "  Skipping download"
else
    echo "[DOWNLOAD] GCC ARM32 from AOSP"
    git clone --depth=1 -b android-9.0.0_r1 \
        https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/${GCC_ARM32_VERSION} \
        "$GCC_ARM32_DIR" || {
        echo "[ERROR] Failed to clone GCC ARM32"
        exit 1
    }
    # Remove git history
    rm -rf "$GCC_ARM32_DIR/.git"
    echo "  [OK] GCC ARM32 installed"
fi

# Verify GCC ARM32
if [ -x "$GCC_ARM32_DIR/bin/arm-linux-androideabi-gcc" ]; then
    GCC32_VER=$("$GCC_ARM32_DIR/bin/arm-linux-androideabi-gcc" --version | head -1)
    echo "[VERIFY] $GCC32_VER"
else
    echo "[ERROR] GCC ARM32 binary not found"
    exit 1
fi

echo ""
echo "================================================="
echo "Toolchain Setup Complete!"
echo "================================================="
echo ""
echo "Installed toolchains:"
echo "  Clang:     $CLANG_DIR"
echo "  GCC ARM64: $GCC_ARM64_DIR"
echo "  GCC ARM32: $GCC_ARM32_DIR"
echo ""
echo "Disk usage:"
du -sh "$TOOLCHAIN_DIR"/* 2>/dev/null || true
echo ""
echo "Total: $(du -sh "$TOOLCHAIN_DIR" | cut -f1)"
echo ""
echo "Next step: Run ./build-kernel.sh to compile kernel"
echo "================================================="

# Create environment file for manual builds
ENV_FILE="$TOOLCHAIN_DIR/env.sh"
cat > "$ENV_FILE" << EOF
#!/bin/bash
# AOSP Toolchain Environment
# Source this file: source $ENV_FILE

export CLANG_DIR="$CLANG_DIR"
export GCC_ARM64_DIR="$GCC_ARM64_DIR"
export GCC_ARM32_DIR="$GCC_ARM32_DIR"

export PATH="\$CLANG_DIR/bin:\$GCC_ARM64_DIR/bin:\$GCC_ARM32_DIR/bin:\$PATH"

echo "Toolchain environment loaded:"
echo "  Clang:  \$(clang --version | head -1)"
echo "  GCC64:  \$(aarch64-linux-android-gcc --version | head -1)"
echo "  GCC32:  \$(arm-linux-androideabi-gcc --version | head -1)"
EOF

chmod +x "$ENV_FILE"
echo "[CREATED] Environment file: $ENV_FILE"
echo "  Usage: source $ENV_FILE"
