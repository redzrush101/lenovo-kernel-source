# Building MT6765 Kernel with AOSP Clang

## Quick Start

```bash
# 1. Setup toolchains (one-time, ~500MB download)
./setup-toolchains.sh

# 2. Build kernel
./build-kernel.sh

# 3. Flash to device
adb reboot bootloader
fastboot flash boot ../out/target/product/*/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb
fastboot reboot
```

---

## Detailed Instructions

### First Time Setup

1. **Download AOSP Toolchains**
   ```bash
   cd kernel-4.9
   ./setup-toolchains.sh
   ```
   
   This downloads:
   - **Clang 5.0** (clang-4691093) - Same as original Lenovo build
   - **GCC 4.9 ARM64** - For linking
   - **GCC 4.9 ARM32** - For compat vDSO support
   
   Total size: ~500MB
   Location: `../toolchains/` (one level up from kernel-4.9)

2. **Verify Installation**
   ```bash
   ls -la ../toolchains/
   # Should show:
   #   clang-4691093/
   #   gcc-arm64/
   #   gcc-arm32/
   #   env.sh
   ```

### Building the Kernel

**Basic build:**
```bash
./build-kernel.sh
```

**Build different variant:**
```bash
KERNEL_PROJECT=achilles6_prc_call ./build-kernel.sh
KERNEL_PROJECT=achilles6_row_call ./build-kernel.sh
```

**Verbose build (see all commands):**
```bash
VERBOSE=1 ./build-kernel.sh
```

**Clean builds:**
```bash
./build-kernel.sh clean       # Remove output only
./build-kernel.sh mrproper    # Deep clean + remove output
```

**Configure kernel:**
```bash
./build-kernel.sh menuconfig
```

### Available Kernel Variants

| Defconfig | Device | Region | Debug |
|-----------|--------|--------|-------|
| `achilles6_row_wifi` | WiFi only | Global | No |
| `achilles6_row_wifi_debug` | WiFi only | Global | Yes |
| `achilles6_row_call` | LTE | Global | No |
| `achilles6_row_call_debug` | LTE | Global | Yes |
| `achilles6_prc_wifi` | WiFi only | China | No |
| `achilles6_prc_call` | LTE | China | No |

Default: `achilles6_row_wifi`

---

## Build Output

### Artifacts Location
```
../out/target/product/<PROJECT>/obj/KERNEL_OBJ/
├── arch/arm64/boot/
│   └── Image.gz-dtb          ← **Flash this file**
├── include/generated/
│   └── compile.h             ← Verify compiler used
├── build.log                 ← Full build log
└── *.ko                      ← Kernel modules (in various dirs)
```

### What Gets Built

1. **Kernel Image**: `Image.gz-dtb`
   - Compressed kernel + Device Tree Blobs
   - Ready to flash to boot partition

2. **Kernel Modules**: `*.ko` files
   - MediaTek drivers (mtk_*)
   - WiFi, Bluetooth, Sensors, etc.
   - Installed to `../../vendor/lib/modules/`

3. **Build Log**: `build.log`
   - Full compilation output
   - Warning/error analysis

---

## Flashing to Device

### Prerequisites
- Device with unlocked bootloader
- Working `adb` and `fastboot`
- Backup of current boot image!

### Method 1: Fastboot (Recommended)
```bash
# Reboot to bootloader
adb reboot bootloader

# Flash kernel
fastboot flash boot ../out/target/product/*/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb

# Reboot
fastboot reboot

# Monitor boot
adb wait-for-device
adb logcat -b kernel | grep -E "(mt6765|mtk)"
```

### Method 2: Create Boot Image
```bash
# If you need to pack into boot.img (requires original ramdisk)
# ... add your boot.img packing commands here ...
```

---

## Verification

### 1. Check Compiler Used
```bash
# After build completes:
grep "LINUX_COMPILER" ../out/target/product/*/obj/KERNEL_OBJ/include/generated/compile.h

# Should show: clang version 5.0.something
```

### 2. Verify MT6765 Drivers Built
```bash
find ../out/target/product/*/obj/KERNEL_OBJ -name "*.ko" | grep -i mtk | wc -l
# Should show: ~50-100 modules
```

### 3. On Device (After Flashing)
```bash
# Check kernel version
adb shell uname -r

# Check loaded modules
adb shell lsmod | grep mtk

# Verify MT6765 platform
adb shell cat /proc/cpuinfo | grep -i "mt6765"

# Check critical subsystems
adb shell cat /sys/class/power_supply/battery/capacity    # Battery
adb shell cat /sys/class/thermal/thermal_zone0/temp       # Thermals
adb shell dumpsys SurfaceFlinger | grep -i fps            # Display
```

---

## Troubleshooting

### "Toolchains not found"
```bash
# Run setup first
./setup-toolchains.sh

# If it fails, check network:
ping android.googlesource.com
```

### "CONFIG_MACH_MT6765 not enabled"
```bash
# Wrong defconfig name. Check available configs:
ls arch/arm64/configs/achilles6_*

# Use correct name:
KERNEL_PROJECT=achilles6_row_wifi ./build-kernel.sh
```

### Build Errors
```bash
# Check build log
less ../out/target/product/*/obj/KERNEL_OBJ/build.log

# Clean and retry
./build-kernel.sh clean
./build-kernel.sh
```

### Device Won't Boot
```bash
# Flash back to original kernel (keep backup!)
fastboot flash boot kernel-backup.img
fastboot reboot

# Check boot log for clues
adb wait-for-device
adb logcat -b kernel > boot-fail.log
```

### "No space left on device"
```bash
# Check disk space
df -h ../out/

# Clean old builds
./build-kernel.sh clean
```

---

## Advanced Usage

### Manual Compilation (for debugging)
```bash
# Load toolchain environment
source ../toolchains/env.sh

# Generate config manually
make O=../out/... ARCH=arm64 achilles6_row_wifi_defconfig

# Build with full command visibility
PATH="$CLANG_DIR/bin:$GCC_ARM64_DIR/bin:$GCC_ARM32_DIR/bin:$PATH" \
make -j$(nproc) V=1 O=../out/... ARCH=arm64 \
     CC=clang \
     CLANG_TRIPLE=aarch64-linux-gnu- \
     CROSS_COMPILE=aarch64-linux-android- \
     CROSS_COMPILE_ARM32=arm-linux-androideabi-
```

### Cross-Variant Comparison
```bash
# Build multiple variants and compare
for variant in achilles6_row_wifi achilles6_row_call achilles6_prc_call; do
    echo "Building $variant..."
    KERNEL_PROJECT=$variant ./build-kernel.sh
    cp ../out/target/product/$variant/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb \
       kernels/$variant-$(date +%Y%m%d).img
done
```

### Warning Analysis
```bash
# After build, analyze warnings by type
grep "warning:" ../out/target/product/*/obj/KERNEL_OBJ/build.log | \
    sed 's/.*warning: //' | cut -d'[' -f1 | sort | uniq -c | sort -rn

# Find warnings in specific subsystem
grep "drivers/misc/mediatek" ../out/target/product/*/obj/KERNEL_OBJ/build.log | \
    grep -i warning
```

---

## For 4.9.337 Upgrade

When upgrading to 4.9.337, **keep using the same toolchains**:

```bash
# After rebasing to 4.9.337
git checkout upgrade/mt6765-4.9.337

# Use SAME build script
./build-kernel.sh

# Compare warnings
diff warnings-4.9.117.txt warnings-4.9.337.txt
```

The toolchains are compatible with both 4.9.117 and 4.9.337.

---

## References

- [AOSP Clang Guide](https://github.com/nathanchance/android-kernel-clang) - Original compilation guide
- [ClangBuiltLinux](https://github.com/ClangBuiltLinux/linux) - Upstream Clang kernel support
- [AOSP Clang Prebuilts](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/) - Official toolchains

---

## Getting Help

If build fails:

1. Check build log: `../out/target/product/*/obj/KERNEL_OBJ/build.log`
2. Verify toolchains: `ls -la ../toolchains/`
3. Clean and retry: `./build-kernel.sh mrproper && ./build-kernel.sh`
4. Check disk space: `df -h`

Open an issue with:
- Full build log
- Toolchain versions: `source ../toolchains/env.sh` (shows versions)
- Kernel version: `head -5 Makefile`
