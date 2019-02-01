help:: vlm.help

vlm.help:
	$(ECHO) "\n--- VLM target helpers ---"
	$(ECHO) " vlm-reserve               	: reserve the VLM target for yourself if not reserved"
	$(ECHO) " vlm-unreserve             	: unreserve the VLM target"
	$(ECHO) " vlm-connect-console       	: connect to the serial port of the VLM target through telnet"

vlm-check-id:
	@if [ "$(VLM_ID)" == "" ]; then \
		echo "$(TARGET) is not a VLM target" ;\
		exit 1 ;\
	fi

vlm-reserve: vlm-check-id
	@TARGET_USER=$$($(VLMTOOL) getAttr -t $(VLM_ID) all | grep -i "reserved by" | cut -d ":" -f 2 | tr -d " ") ; \
	if [ ! -z $$TARGET_USER ]; then \
		if [ "$$TARGET_USER" == "$$(whoami)" ]; then \
			echo "Target is already reserved by you!" ; \
		else \
			echo "Target is reserved by $$TARGET_USER." ; \
			echo "Ask the person to unreserve it before using it." ; \
			exit 1; \
		fi \
	else \
		$(VLMTOOL) reserve -t $(VLM_ID) ; \
		echo "Target successfully reserved!" ; \
	fi

vlm-unreserve: vlm-check-id
	@TARGET_USER=$$($(VLMTOOL) getAttr -t $(VLM_ID) all | grep -i "reserved by" | cut -d ":" -f 2 | tr -d " ") ; \
	if [ ! -z $$TARGET_USER ]; then \
		if [ "$$TARGET_USER" == "$$(whoami)" ]; then \
			echo "Unreserving target.." ; \
			$(VLMTOOL) unreserve -t $(VLM_ID); \
		else \
			echo "Target is reserved by $$TARGET_USER." ; \
			echo "You cannot unreserve it yourself." ; \
			exit 1 ; \
		fi \
	else \
		echo "Target is already unreserved." ; \
	fi

vlm-connect-console: vlm-check-id
	@TARGET_USER=$$($(VLMTOOL) getAttr -t $(VLM_ID) all | grep -i "reserved by" | cut -d ":" -f 2 | tr -d " ") ; \
	if [ ! -z $$TARGET_USER ]; then \
		if [ "$$TARGET_USER" == "$$(whoami)" ]; then \
			echo "Connecting to telnet server.." ; \
			TELNET_INFO=$$($(VLMTOOL) getAttr -t $(VLM_ID) all | grep -i 'terminal' | cut -d ':' -f 2 ) ; \
			TELNET_INFO=($$TELNET_INFO) ; \
			telnet $${TELNET_INFO[0]} $$(($${TELNET_INFO[1]}+2000)) ; \
		else \
			echo "Target is reserved by $$TARGET_USER." ; \
			echo "You cannot use it at this time, exiting..." ; \
			exit 1 ; \
		fi \
	else \
		echo "Target is unreserved! You need to reserve it before using it." ; \
		echo "You can do that by running \"make vlm-reserve\"." ; \
		exit 1 ; \
	fi

