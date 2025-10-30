#!/bin/bash
# Modern Toolchain Build Script for MT6765 Kernel
# Supports flexible toolchain configuration for 4.9.117 -> 4.9.337 upgrade
set -e

#==============================================================================
# TOOLCHAIN CONFIGURATION
#==============================================================================

# Project configuration
PROJECT=${KERNEL_PROJECT:-achilles6_row_wifi_defconfig}
CONFIG=${PROJECT}_defconfig

# Toolchain paths (override via environment variables)
# Option 1: Android NDK r21+ (recommended for compatibility)
CLANG_PREBUILT=${CLANG_PREBUILT:-/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64}

# Option 2: System toolchain (requires clang-10 or newer)
CLANG_BIN=${CLANG_BIN:-$(which clang-12 || which clang-11 || which clang-10 || which clang 2>/dev/null || echo "")}

# GCC cross-compiler (for linking)
GCC_CROSS_COMPILE=${GCC_CROSS_COMPILE:-aarch64-linux-gnu-}

# Build output directory
OUT_DIR=${OUT_DIR:-$(pwd)/../out/target/product/${PROJECT}/obj/KERNEL_OBJ}

#==============================================================================
# TOOLCHAIN DETECTION & VALIDATION
#==============================================================================

detect_toolchain() {
    echo "================================================="
    echo "MT6765 Kernel Build - Toolchain Detection"
    echo "================================================="
    
    # Prefer Android NDK toolchain
    if [ -d "$CLANG_PREBUILT" ]; then
        export CC="$CLANG_PREBUILT/bin/clang"
        export PATH="$CLANG_PREBUILT/bin:$PATH"
        CLANG_VERSION=$($CC --version | head -1)
        echo "[INFO] Using Android NDK Clang: $CLANG_VERSION"
        echo "[INFO] Path: $CLANG_PREBUILT"
    elif [ -n "$CLANG_BIN" ] && [ -x "$CLANG_BIN" ]; then
        export CC="$CLANG_BIN"
        CLANG_VERSION=$($CC --version | head -1)
        echo "[INFO] Using system Clang: $CLANG_VERSION"
        echo "[INFO] Path: $CLANG_BIN"
    else
        echo "[ERROR] No suitable Clang compiler found!"
        echo ""
        echo "Please install one of the following:"
        echo "  1. Android NDK r21+ (recommended):"
        echo "     wget https://dl.google.com/android/repository/android-ndk-r21e-linux-x86_64.zip"
        echo "     unzip android-ndk-r21e-linux-x86_64.zip -d /opt/"
        echo "     export CLANG_PREBUILT=/opt/android-ndk-r21e/toolchains/llvm/prebuilt/linux-x86_64"
        echo ""
        echo "  2. System Clang 10+ (Ubuntu/Debian):"
        echo "     sudo apt install clang-12 lld-12"
        echo "     export CLANG_BIN=/usr/bin/clang-12"
        echo ""
        exit 1
    fi
    
    # Check cross-compiler
    if ! command -v ${GCC_CROSS_COMPILE}gcc &> /dev/null; then
        echo "[ERROR] Cross-compiler not found: ${GCC_CROSS_COMPILE}gcc"
        echo ""
        echo "Install with:"
        echo "  sudo apt install gcc-aarch64-linux-gnu"
        echo ""
        exit 1
    fi
    
    GCC_VERSION=$(${GCC_CROSS_COMPILE}gcc --version | head -1)
    echo "[INFO] Using cross-compiler: $GCC_VERSION"
    echo "[INFO] Cross-compile prefix: $GCC_CROSS_COMPILE"
    
    # Clang version check for 4.9.337 upgrade
    CLANG_MAJOR=$($CC --version | grep -oP 'version \K[0-9]+' | head -1)
    if [ "$CLANG_MAJOR" -lt 8 ]; then
        echo "[WARN] Clang version < 8 detected. For 4.9.337 upgrade, use Clang 10+."
        echo "[WARN] Build may succeed but expect many warnings."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo "================================================="
    echo ""
}

#==============================================================================
# WARNING SUPPRESSION (for 4.9.337 upgrade)
#==============================================================================

# Additional CFLAGS for new Clang warnings (customize as needed)
EXTRA_CFLAGS=""

# Common warnings with Clang 10+ on 4.9 kernels
if [ "$CLANG_MAJOR" -ge 10 ]; then
    echo "[INFO] Applying Clang 10+ warning suppressions"
    
    # These are EXPECTED warnings that won't affect functionality
    # Disable them as errors but keep visible in logs
    EXTRA_CFLAGS+="-Wno-error=implicit-fallthrough "
    EXTRA_CFLAGS+="-Wno-error=address-of-packed-member "
    EXTRA_CFLAGS+="-Wno-error=format-overflow "
    EXTRA_CFLAGS+="-Wno-error=unused-const-variable "
    
    # MT6765-specific: MediaTek drivers have enum type mismatches
    EXTRA_CFLAGS+="-Wno-error=enum-conversion "
    EXTRA_CFLAGS+="-Wno-error=sometimes-uninitialized "
    
    # For 4.9.337 upgrade testing, log ALL warnings
    export KBUILD_CFLAGS_KERNEL="$EXTRA_CFLAGS"
fi

#==============================================================================
# BUILD FUNCTIONS
#==============================================================================

build_config() {
    echo "[BUILD] Generating kernel configuration: $CONFIG"
    make -j$(nproc) \
        -C $(pwd) \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CROSS_COMPILE="$GCC_CROSS_COMPILE" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CC="$CC" \
        "$CONFIG"
    
    # Verify critical MT6765 configs
    echo "[CHECK] Verifying MT6765 configuration..."
    grep -q "CONFIG_MACH_MT6765=y" "$OUT_DIR/.config" || {
        echo "[ERROR] CONFIG_MACH_MT6765 not enabled!"
        exit 1
    }
    echo "[OK] MT6765 SoC configuration verified"
}

build_kernel() {
    echo "[BUILD] Building kernel image and DTBs"
    
    # Save build log for warning analysis
    BUILD_LOG="$OUT_DIR/build-$(date +%Y%m%d-%H%M%S).log"
    
    make -j$(nproc) V=1 \
        -C $(pwd) \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CROSS_COMPILE="$GCC_CROSS_COMPILE" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CC="$CC" \
        2>&1 | tee "$BUILD_LOG"
    
    echo "[LOG] Build log saved: $BUILD_LOG"
    
    # Analyze warnings
    echo ""
    echo "================================================="
    echo "Build Warning Summary"
    echo "================================================="
    grep -i "warning:" "$BUILD_LOG" | sort | uniq -c | sort -rn | head -20 || echo "No warnings found"
    echo "================================================="
}

build_modules() {
    echo "[BUILD] Building kernel modules"
    make -j$(nproc) \
        -C $(pwd) \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CROSS_COMPILE="$GCC_CROSS_COMPILE" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CC="$CC" \
        modules
}

install_modules() {
    echo "[BUILD] Installing modules to vendor partition"
    VENDOR_PATH="$OUT_DIR/../../vendor"
    mkdir -p "$VENDOR_PATH"
    
    make -j$(nproc) \
        -C $(pwd) \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CROSS_COMPILE="$GCC_CROSS_COMPILE" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CC="$CC" \
        modules_install \
        INSTALL_MOD_PATH="$VENDOR_PATH"
}

show_artifacts() {
    echo ""
    echo "================================================="
    echo "Build Artifacts"
    echo "================================================="
    
    KERNEL_IMG="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    if [ -f "$KERNEL_IMG" ]; then
        echo "[OK] Kernel image: $KERNEL_IMG"
        ls -lh "$KERNEL_IMG"
    else
        echo "[ERROR] Kernel image not found!"
        exit 1
    fi
    
    # Check for critical MT6765 drivers
    echo ""
    echo "Checking critical MediaTek modules..."
    find "$OUT_DIR" -name "*.ko" | grep -E "(mtk|mediatek)" | head -10
    
    echo "================================================="
}

#==============================================================================
# MAIN BUILD FLOW
#==============================================================================

main() {
    detect_toolchain
    
    echo "Starting build for: $PROJECT"
    echo "Output directory: $OUT_DIR"
    echo ""
    
    build_config
    build_kernel
    build_modules
    install_modules
    show_artifacts
    
    echo ""
    echo "[SUCCESS] Build completed successfully!"
    echo ""
    echo "Next steps for 4.9.337 upgrade testing:"
    echo "  1. Review build log for unexpected errors"
    echo "  2. Flash kernel: fastboot flash boot $OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    echo "  3. Monitor boot: adb logcat -b kernel"
    echo "  4. Check MT6765 drivers: adb shell lsmod | grep mtk"
}

# Run with error handling
trap 'echo "[ERROR] Build failed at line $LINENO"; exit 1' ERR

main "$@"
