# MT6765 Kernel Build - Quick Start

## ⚡ Two Commands to Build

```bash
# Step 1: Setup toolchains (one-time, ~500MB download)
./setup-toolchains.sh

# Step 2: Build kernel
./build-kernel.sh
```

That's it! Kernel image will be at:
```
../out/target/product/achilles6_row_wifi/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb
```

---

## 📁 New File Structure

```
lenovo_kernel_source/
├── kernel-4.9/                     ← You are here
│   ├── setup-toolchains.sh         ← NEW: Download AOSP toolchains
│   ├── build-kernel.sh             ← NEW: Build script (replaces compile_kernel.sh)
│   ├── README-BUILD.md             ← NEW: Detailed documentation
│   ├── QUICKSTART.md               ← NEW: This file
│   ├── compile_kernel.sh           ← OLD: Keep for reference
│   └── [kernel source...]
│
└── toolchains/                     ← NEW: Auto-created by setup
    ├── clang-4691093/              ← Clang 5.0 (same as original)
    ├── gcc-arm64/                  ← GCC 4.9 for ARM64
    ├── gcc-arm32/                  ← GCC 4.9 for ARM32
    └── env.sh                      ← Environment helper
```

---

## 🎯 What Changed

### ✅ NEW System (Recommended)
- ✅ **Portable**: No hardcoded `/opt/m10/` paths
- ✅ **Automatic**: Downloads toolchains from AOSP
- ✅ **Compatible**: Works with 4.9.117 AND 4.9.337
- ✅ **Follows**: Official AOSP Clang compilation guide
- ✅ **Verified**: Same Clang 5.0 as original Lenovo build

### 📦 OLD System (Still Works)
- `compile_kernel.sh` - Original script (kept for reference)
- Requires manual `/opt/m10/prebuilts/` setup
- Not needed anymore!

---

## 📋 Build Different Variants

```bash
# WiFi-only (default)
./build-kernel.sh

# LTE variants
KERNEL_PROJECT=achilles6_row_call ./build-kernel.sh
KERNEL_PROJECT=achilles6_prc_call ./build-kernel.sh

# Debug builds
KERNEL_PROJECT=achilles6_row_wifi_debug ./build-kernel.sh

# China variants
KERNEL_PROJECT=achilles6_prc_wifi ./build-kernel.sh
```

---

## 🔧 Common Commands

```bash
# Clean build
./build-kernel.sh clean

# Deep clean
./build-kernel.sh mrproper

# Configure kernel
./build-kernel.sh menuconfig

# Verbose output
VERBOSE=1 ./build-kernel.sh

# Show help
./build-kernel.sh help
```

---

## 📱 Flash to Device

```bash
adb reboot bootloader
fastboot flash boot ../out/target/product/*/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb
fastboot reboot
```

**⚠️ WARNING**: Make backup of original kernel first!

---

## 🚀 For 4.9.337 Upgrade

The toolchains work for **both** 4.9.117 (current) and 4.9.337 (upgrade):

```bash
# Setup toolchains once
./setup-toolchains.sh

# Build current kernel (4.9.117) - test it works
./build-kernel.sh

# After upgrade to 4.9.337
git checkout upgrade/mt6765-4.9.337

# Use SAME build script
./build-kernel.sh
```

No toolchain changes needed during upgrade!

---

## ❓ Troubleshooting

### "Toolchains not found"
```bash
./setup-toolchains.sh  # Run this first!
```

### Build fails
```bash
./build-kernel.sh clean
./build-kernel.sh
```

### Need more help?
```bash
cat README-BUILD.md    # Full documentation
./build-kernel.sh help # Command options
```

---

## ⏱️ Timing Expectations

| Task | First Time | Subsequent |
|------|-----------|------------|
| Setup toolchains | ~5-10 min | N/A |
| Full kernel build | ~5-10 min | Same |
| Incremental build | N/A | ~1-2 min |

(Timing on modern CPU with fast internet)

---

## ✅ Next Steps

1. **Test current kernel** (4.9.117):
   ```bash
   ./setup-toolchains.sh
   ./build-kernel.sh
   # Flash and verify device works
   ```

2. **After successful test**, proceed with 4.9.337 upgrade:
   - Follow `custom/plan.md`
   - Use same `./build-kernel.sh`
   - Compare warnings

---

## 📚 Documentation

- `README-BUILD.md` - Full build documentation
- `custom/plan.md` - Kernel upgrade plan
- `custom/toolchain-upgrade-guide.md` - Toolchain details
- [AOSP Clang Guide](https://github.com/nathanchance/android-kernel-clang)
