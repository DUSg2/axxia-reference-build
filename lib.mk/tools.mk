# tools.mk

# Tools used
# Define V=1 to echo everything
V 	?= 0
ifneq ($(V),1)
Q=@
endif

CD             := $(Q)cd
CHMOD          := $(Q)chmod
CP             := $(Q)cp
ECHO           := $(Q)/bin/echo -e
FIND           := $(Q)find
GIT            := $(Q)git
MAKE           := $(Q)make -s
MKDIR          := $(Q)mkdir -p
MV             := $(Q)mv
RM             := $(Q)rm -f
RSYNC          := $(Q)rsync
SCP            ?= $(Q)scp
SED            := $(Q)sed
SSH            ?= $(Q)ssh
SSHPASS	       := $(Q)sshpass
TAR            ?= $(Q)tar
XMLSTARLET     := $(Q)xmlstarlet
XTERM          ?= $(Q)x-terminal-emulator
NO_STDOUT	= >/dev/null

# Echo helpers
INFO_MSG	= [i]
COL_NC		= \e[0m
COL_LIGHT_GREEN = \e[1;32m
COL_LIGHT_RED	= \e[1;31m
GREEN_TICK	= [$(COL_LIGHT_GREEN)✓$(COL_NC)]
RED_CROSS	= [$(COL_LIGHT_RED)✗$(COL_NC)]
