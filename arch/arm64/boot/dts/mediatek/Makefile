dtb-$(CONFIG_ARCH_MEDIATEK) += mt6755-evb.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += mt6795-evb.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += mt8173-evb.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += auto2712m1v1-ivi-boot.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += auto2712m1v1-ivi_agl-vp1-boot.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += auto2712m1v1-initramfs.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += auto2712m1v1-ivi-nand-boot.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += mt6765.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += mt6761.dtb

# Lenovo MT6765 (achilles6) product overlays
dtb-$(CONFIG_ARCH_MEDIATEK) += achilles6_prc_wifi.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += achilles6_prc_call.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += achilles6_row_call.dtb
dtb-$(CONFIG_ARCH_MEDIATEK) += achilles6_row_wifi.dtb

ifeq ($(strip $(CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE)), y)
dtb-y += $(addsuffix .dtb, $(notdir $(subst $\",,$(CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES))))
endif

ifeq ($(strip $(CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE)), y)
dtb-y += $(addsuffix .dtb, $(notdir $(subst $\",,$(CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES))))
endif

always		:= $(dtb-y)
subdir-y	:= $(dts-dirs)
clean-files	:= *.dtb
