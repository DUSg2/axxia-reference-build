# tools.mk

# Tools used
# Define V=1 to echo everything
V 	?= 0
ifneq ($(V),1)
Q=@
endif

CD		:= $(Q)cd
CP		:= $(Q)cp
ECHO		:= $(Q)/bin/echo -e
GIT		:= $(Q)git
MAKE		:= $(Q)make -s
MKDIR		:= $(Q)mkdir -p
MV		:= $(Q)mv
RM		:= $(Q)rm -f
RSYNC		:= $(Q)rsync -e "ssh -i $(OUTDIR)/netinstall.id_rsa"
SCP		?= $(Q)scp
SED		:= $(Q)sed
SSH		?= $(Q)ssh
SSHPASS		:= $(Q)sshpass
TAR		?= $(Q)tar
XMLSTARLET	:= $(Q)xmlstarlet
XTERM		?= $(Q)x-terminal-emulator
