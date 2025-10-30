#!/bin/bash
# MT6765 Kernel Build Script
# Based on AOSP Clang compilation guide
# Compatible with 4.9.117 (current) and 4.9.337 (upgrade target)

set -e

#==============================================================================
# CONFIGURATION
#==============================================================================

# Kernel source directory
KERNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Toolchain directory (one level up from kernel-4.9)
TOOLCHAIN_BASE="$(dirname "$KERNEL_DIR")/toolchains"

# Project configuration
PROJECT=${KERNEL_PROJECT:-achilles6_row_wifi}
CONFIG=${PROJECT}_defconfig

# Output directory
OUT_DIR=${OUT_DIR:-"$(dirname "$KERNEL_DIR")/out/target/product/${PROJECT}/obj/KERNEL_OBJ"}

# Build options
JOBS=${JOBS:-$(nproc --all)}
VERBOSE=${VERBOSE:-0}  # Set to 1 for verbose output

#==============================================================================
# TOOLCHAIN DETECTION
#==============================================================================

detect_toolchains() {
    echo "================================================="
    echo "MT6765 Kernel Build (4.9.117)"
    echo "================================================="
    echo "Kernel source: $KERNEL_DIR"
    echo "Output: $OUT_DIR"
    echo ""
    
    # Check if toolchains exist
    if [ ! -d "$TOOLCHAIN_BASE" ]; then
        echo "[ERROR] Toolchains not found at: $TOOLCHAIN_BASE"
        echo ""
        echo "Run setup first:"
        echo "  cd $KERNEL_DIR"
        echo "  ./setup-toolchains.sh"
        echo ""
        exit 1
    fi
    
    # Detect Clang
    CLANG_DIR=$(find "$TOOLCHAIN_BASE" -maxdepth 1 -type d -name "clang-*" | head -1)
    if [ -z "$CLANG_DIR" ] || [ ! -x "$CLANG_DIR/bin/clang" ]; then
        echo "[ERROR] Clang not found in $TOOLCHAIN_BASE"
        echo "Run: ./setup-toolchains.sh"
        exit 1
    fi
    
    # Detect GCC ARM64
    GCC_ARM64_DIR=$(find "$TOOLCHAIN_BASE" -maxdepth 1 -type d -name "gcc-arm64" | head -1)
    if [ -z "$GCC_ARM64_DIR" ] || [ ! -d "$GCC_ARM64_DIR/bin" ]; then
        echo "[ERROR] GCC ARM64 not found in $TOOLCHAIN_BASE"
        echo "Run: ./setup-toolchains.sh"
        exit 1
    fi
    
    # Detect GCC ARM32
    GCC_ARM32_DIR=$(find "$TOOLCHAIN_BASE" -maxdepth 1 -type d -name "gcc-arm32" | head -1)
    if [ -z "$GCC_ARM32_DIR" ] || [ ! -d "$GCC_ARM32_DIR/bin" ]; then
        echo "[ERROR] GCC ARM32 not found in $TOOLCHAIN_BASE"
        echo "Run: ./setup-toolchains.sh"
        exit 1
    fi
    
    # Setup PATH
    export PATH="$CLANG_DIR/bin:$GCC_ARM64_DIR/bin:$GCC_ARM32_DIR/bin:$PATH"
    
    # Display toolchain info
    echo "Toolchains detected:"
    CLANG_VERSION=$(clang --version | head -1)
    GCC64_VERSION=$(aarch64-linux-android-gcc --version | head -1 | cut -d')' -f2)
    GCC32_VERSION=$(arm-linux-androideabi-gcc --version | head -1 | cut -d')' -f2)
    
    echo "  Clang:  $CLANG_VERSION"
    echo "  GCC64:  $GCC64_VERSION"
    echo "  GCC32:  $GCC32_VERSION"
    echo ""
}

#==============================================================================
# BUILD FUNCTIONS (Following AOSP Clang guide)
#==============================================================================

make_defconfig() {
    echo "[1/4] Generating kernel configuration"
    echo "  Config: $CONFIG"
    
    make -C "$KERNEL_DIR" \
        O="$OUT_DIR" \
        ARCH=arm64 \
        "$CONFIG"
    
    # Verify MT6765 config
    if ! grep -q "CONFIG_MACH_MT6765=y" "$OUT_DIR/.config"; then
        echo "[ERROR] CONFIG_MACH_MT6765 not enabled in $CONFIG"
        exit 1
    fi
    
    echo "  [OK] Configuration ready"
    echo ""
}

build_kernel() {
    echo "[2/4] Building kernel image"
    
    local v_flag=""
    [ "$VERBOSE" = "1" ] && v_flag="V=1"
    
    # Build command from AOSP guide:
    # PATH="<clang>:<gcc64>:<gcc32>:${PATH}" \
    # make -j$(nproc) O=out ARCH=arm64 CC=clang \
    #      CLANG_TRIPLE=aarch64-linux-gnu- \
    #      CROSS_COMPILE=aarch64-linux-android- \
    #      CROSS_COMPILE_ARM32=arm-linux-androideabi-
    
    PATH="$CLANG_DIR/bin:$GCC_ARM64_DIR/bin:$GCC_ARM32_DIR/bin:$PATH" \
    make -j${JOBS} ${v_flag} \
        -C "$KERNEL_DIR" \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- \
        2>&1 | tee "$OUT_DIR/build.log"
    
    echo "  [OK] Kernel image built"
    echo ""
}

build_modules() {
    echo "[3/4] Building kernel modules"
    
    PATH="$CLANG_DIR/bin:$GCC_ARM64_DIR/bin:$GCC_ARM32_DIR/bin:$PATH" \
    make -j${JOBS} \
        -C "$KERNEL_DIR" \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- \
        modules
    
    echo "  [OK] Modules built"
    echo ""
}

install_modules() {
    echo "[4/4] Installing modules"
    
    local vendor_dir="$OUT_DIR/../../vendor"
    mkdir -p "$vendor_dir"
    
    PATH="$CLANG_DIR/bin:$GCC_ARM64_DIR/bin:$GCC_ARM32_DIR/bin:$PATH" \
    make -j${JOBS} \
        -C "$KERNEL_DIR" \
        O="$OUT_DIR" \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- \
        modules_install \
        INSTALL_MOD_PATH="$vendor_dir"
    
    echo "  [OK] Modules installed to $vendor_dir"
    echo ""
}

#==============================================================================
# VERIFICATION
#==============================================================================

verify_build() {
    echo "================================================="
    echo "Build Verification"
    echo "================================================="
    
    # Check kernel image
    local kernel_img="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    if [ -f "$kernel_img" ]; then
        echo "[OK] Kernel image: $kernel_img"
        ls -lh "$kernel_img"
    else
        echo "[ERROR] Kernel image not found!"
        exit 1
    fi
    
    # Verify compiler (from AOSP guide)
    local compile_h="$OUT_DIR/include/generated/compile.h"
    if [ -f "$compile_h" ]; then
        echo ""
        echo "Compiler verification (from compile.h):"
        grep "LINUX_COMPILER" "$compile_h" || echo "  [WARN] LINUX_COMPILER not found"
    fi
    
    # Check for MT6765 specific modules
    echo ""
    echo "MediaTek modules (sample):"
    find "$OUT_DIR" -name "*.ko" | grep -i mtk | head -5 || echo "  No modules built"
    
    # Build log analysis
    echo ""
    echo "Build warnings summary:"
    if [ -f "$OUT_DIR/build.log" ]; then
        local warn_count=$(grep -c "warning:" "$OUT_DIR/build.log" || echo "0")
        local err_count=$(grep -c "error:" "$OUT_DIR/build.log" || echo "0")
        echo "  Warnings: $warn_count"
        echo "  Errors: $err_count"
        
        if [ "$err_count" -gt 0 ]; then
            echo ""
            echo "[ERROR] Build had errors! Check $OUT_DIR/build.log"
            exit 1
        fi
    fi
    
    echo "================================================="
}

show_next_steps() {
    echo ""
    echo "Build Complete!"
    echo "================================================="
    echo ""
    echo "Kernel image location:"
    echo "  $OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    echo ""
    echo "Next steps:"
    echo "  1. Flash to device:"
    echo "       adb reboot bootloader"
    echo "       fastboot flash boot $OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    echo "       fastboot reboot"
    echo ""
    echo "  2. Monitor boot:"
    echo "       adb wait-for-device"
    echo "       adb logcat -b kernel | grep -i mt6765"
    echo ""
    echo "  3. Verify drivers:"
    echo "       adb shell lsmod | grep mtk"
    echo ""
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    # Parse arguments
    case "${1:-}" in
        clean)
            echo "Cleaning build directory..."
            rm -rf "$OUT_DIR"
            echo "Done. Run './build-kernel.sh' to rebuild."
            exit 0
            ;;
        mrproper)
            echo "Deep cleaning (mrproper)..."
            make -C "$KERNEL_DIR" mrproper
            rm -rf "$OUT_DIR"
            echo "Done. Run './build-kernel.sh' to rebuild."
            exit 0
            ;;
        menuconfig)
            detect_toolchains
            make_defconfig
            echo "Starting menuconfig..."
            make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 menuconfig
            exit 0
            ;;
        help|-h|--help)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  (none)       Build kernel (default)"
            echo "  clean        Remove build output"
            echo "  mrproper     Deep clean"
            echo "  menuconfig   Configure kernel"
            echo "  help         Show this message"
            echo ""
            echo "Environment variables:"
            echo "  KERNEL_PROJECT  Defconfig name (default: achilles6_row_wifi)"
            echo "  JOBS            Parallel jobs (default: $(nproc --all))"
            echo "  VERBOSE         Verbose build: 0 or 1 (default: 0)"
            echo "  OUT_DIR         Output directory"
            echo ""
            echo "Examples:"
            echo "  ./build-kernel.sh                    # Build with defaults"
            echo "  KERNEL_PROJECT=achilles6_prc_call ./build-kernel.sh"
            echo "  VERBOSE=1 ./build-kernel.sh          # Verbose output"
            echo ""
            exit 0
            ;;
    esac
    
    # Standard build flow
    detect_toolchains
    make_defconfig
    build_kernel
    build_modules
    install_modules
    verify_build
    show_next_steps
}

# Error handling
trap 'echo "[ERROR] Build failed! Check output above."; exit 1' ERR

main "$@"
