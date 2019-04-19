TARGET     ?= ase-sim

ifeq ($(TARGET),ase-sim)
SSH_PORT   := $(shell grep -a ^"Host TCP port" build/ase-sim/ase.sim.log 2>/dev/null | grep 22 | cut -d" " -f 4)
SSH_IP     := localhost
endif

ifeq ($(TARGET),vlm_snr1)
SSH_PORT   := 22
SSH_IP     := 128.224.95.194
VLM_ID     := 98981069
endif

ifeq ($(TARGET),vlm_snr2)
SSH_PORT   := 22
SSH_IP     := 128.224.95.160
VLM_ID     := 98981070
endif

SSH_TARGET := root@$(SSH_IP)
SSH_OPT    := -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
SSH_CMD    := $(SSH) -p $(SSH_PORT) $(SSH_OPT) $(SSH_TARGET)
SCP_CMD    := $(SCP) -P $(SSH_PORT) $(SSH_OPT)
