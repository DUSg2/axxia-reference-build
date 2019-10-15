-include $(TOP)/lib.mk/tools.mk

# Default settings
TOP		:= $(shell pwd)
SHELL		:= /bin/bash
HOSTNAME 	?= $(shell hostname)
USER		?= $(shell whoami)

all: help

help::
	$(ECHO) "Current useful make targets"
	$(ECHO) "======================================================="
	$(ECHO) "\n--- build commands ---"
	$(ECHO) " image                     : builds a platform"
	$(ECHO) " clean                     : removes any platform build or samples"
	$(ECHO) " distclean                 : remove $(TOP)/build directory"

# Optional configuration
-include hostconfig-$(HOSTNAME).mk
-include userconfig-$(USER).mk

# Include any additional Makefile components
-include $(TOP)/lib.mk/*.mk

POKY_URL = git://git.yoctoproject.org/poky.git
POKY_REL = e6949336479e611a142834b6d9241514cbaeaf80

OE_URL = https://github.com/openembedded/meta-openembedded.git
OE_REL = 2d088d252624b19df384aecc434d23afb636178f
LAYERS += $(TOP)/build/layers/meta-openembedded
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-oe
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-python
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-networking
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-filesystems
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-perl
LAYERS += $(TOP)/layers/meta-prime-addons

VIRT_URL = git://git.yoctoproject.org/meta-virtualization
VIRT_REL = 7685c7d415e0002c448007960837ae8898cd57a5
LAYERS += $(TOP)/build/layers/meta-virtualization

INTEL_URL=git://git.yoctoproject.org/meta-intel
INTEL_REL=c200851435f39acd2fe4abbf7a05fbf617833964
LAYERS += $(TOP)/build/layers/meta-intel

SECUR_URL = https://git.yoctoproject.org/git/meta-security
SECUR_REL = 31dc4e7532fa7a82060e0b50e5eb8d0414aa7e93
LAYERS += $(TOP)/build/layers/meta-security
LAYERS += $(TOP)/build/layers/meta-security/meta-tpm

ROS_URL = git://github.com/bmwcarit/meta-ros.git
ROS_REL = 7d24d8c960a7ae9eb65789395965e8f1b83b366e
LAYERS += $(TOP)/build/layers/meta-ros

REL_NR=snr_ase_rdk_1910

SNR_BASE=/wr/installs/snr
SNR_ASE_DIR=$(SNR_BASE)/$(REL_NR)/ase
SNR_DPDK_DIR=$(SNR_BASE)/$(REL_NR)
SNR_RDK_DIR=$(SNR_BASE)/$(REL_NR)
SNR_SAMPLES_DIR=$(SNR_BASE)/$(REL_NR)/samples/snr

AXXIA_URL=git@github.com:axxia/meta-intel-axxia.git
AXXIA_REL=$(REL_NR)
LAYERS += $(TOP)/build/layers/meta-intel-axxia/meta-intel-snr
LAYERS += $(TOP)/build/layers/meta-intel-axxia/meta-intel-axxia

ENABLE_AXXIA_RDK=yes
ifeq ($(ENABLE_AXXIA_RDK),yes)

LAYERS += $(TOP)/build/layers/meta-intel-axxia-rdk
AXXIA_RDK_URL=git@github.com:axxia/meta-intel-axxia-rdk.git
AXXIA_RDK_KLM=$(SNR_RDK_DIR)/rdk_klm_src_*xz
AXXIA_RDK_USER=$(SNR_RDK_DIR)/rdk_user_src_*xz

endif

AXXIA_RDK_SAMPLES=$(SNR_SAMPLES_DIR)

MACHINE=axxiax86-64

IMAGE=axxia-image-vcn

define bitbake
        cd build ; \
        source poky/oe-init-build-env ; \
        bitbake $(1)
endef

define bitbake-task
        cd build ; \
        source poky/oe-init-build-env ; \
        bitbake $(1) -c $(2)
endef

$(TOP)/build/poky:

$(TOP)/build/layers/meta-openembedded:
	git -C $(TOP)/build/layers clone $(OE_URL) $@
	git -C $@ checkout $(OE_REL)

$(TOP)/build/layers/meta-virtualization:
	git -C $(TOP)/build/layers clone $(VIRT_URL) $@
	git -C $@ checkout $(VIRT_REL)

$(TOP)/build/layers/meta-intel:
	git -C $(TOP)/build/layers clone $(INTEL_URL) $@
	git -C $@ checkout $(INTEL_REL)

$(TOP)/build/layers/meta-intel-axxia:
	git -C $(TOP)/build/layers clone $(AXXIA_URL) $@
	git -C $@ checkout $(AXXIA_REL)

$(TOP)/build/layers/meta-security:
	git -C $(TOP)/build/layers clone $(SECUR_URL) $@
	git -C $@ checkout $(SECUR_REL)

$(TOP)/build/layers/meta-intel-axxia/meta-intel-snr: $(TOP)/build/layers/meta-intel-axxia

ifeq ($(ENABLE_AXXIA_RDK),yes)

$(TOP)/build/layers/meta-intel-axxia-rdk:
	git -C $(TOP)/build/layers clone $(AXXIA_RDK_URL) $@
	git -C $@ checkout $(AXXIA_REL)
	mkdir -p $@/downloads
	cp $(AXXIA_RDK_KLM) $@/downloads/rdk_klm_src.tar.xz
	cp $(AXXIA_RDK_USER) $@/downloads/rdk_user_src.tar.xz
	mkdir -p $@/downloads/unpacked
	tar -C $@/downloads/unpacked -xf $(AXXIA_RDK_KLM)

$(TOP)/build/layers/meta-ros:
	git -C $(TOP)/build/layers clone $(ROS_URL) $@
	git -C $@ checkout $(ROS_REL)

.PHONY: extract-rdk-patches
extract-rdk-patches:
	mkdir -p $(TOP)/build/extracted-rdk-patches
	git -C build/build/tmp/work-shared/axxiax86-64/kernel-source format-patch -o $(TOP)/build/extracted-rdk-patches before_rdk_commits..after_rdk_commits
endif

.PHONY: build
build:
	$(Q)if [ ! -d $@ ]; then \
                mkdir -p $@/layers ; \
                cd $@ ; \
                git clone $(POKY_URL) ; \
                git -C poky checkout $(POKY_REL) ; \
        fi

# create bitbake build
.PHONY: build/build
build/build: build $(LAYERS)
	$(Q)if [ ! -d $@ ]; then \
		cd build ; \
		source poky/oe-init-build-env ; \
		$(foreach layer, $(LAYERS), bitbake-layers add-layer -F $(layer);) \
		sed -i s/^MACHINE.*/MACHINE\ =\ \"$(MACHINE)\"/g conf/local.conf ; \
		echo "DISTRO = \"intel-axxia-indist\"" >> conf/local.conf ; \
		echo "DISTRO_FEATURES_append = \" rdk-userspace\"" >> conf/local.conf ; \
		echo "RUNTARGET = \"snr\"" >> conf/local.conf ; \
		echo "RELEASE_VERSION = \"$(AXXIA_REL)\"" >> conf/local.conf ; \
		echo "RDK_TOOLS_VERSION = \"$(AXXIA_REL)\"" >> conf/local.conf ; \
		echo "RDK_KLM_VERSION = \"$(AXXIA_REL)\"" >> conf/local.conf ; \
		echo "PREFERRED_PROVIDER_virtual/kernel = \"linux-intel\"" >> conf/local.conf ; \
		echo "PREFERRED_VERSION_linux-intel = \"4.19%\"" >> conf/local.conf ; \
		echo "TOOLCHAIN_TARGET_TASK_append = \" kernel-dev kernel-devsrc\""  >> conf/local.conf ; \
		if [ $(SSTATE_MIRROR_DIR) ]; then \
			echo "SSTATE_MIRRORS ?= \"file://.* file://$(SSTATE_MIRROR_DIR)PATH\"" >> conf/local.conf; \
		fi \
	fi

bbs: build/build
	$(Q)cd build ; \
	source poky/oe-init-build-env ; \
	bash

image: build/build
	$(call bitbake, $(IMAGE))

clean:
	$(RM) -r build/build

distclean:
	$(RM) -r build

