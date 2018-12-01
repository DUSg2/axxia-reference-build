#!/bin/bash

echo "[Info] Running ADK driver test"
modprobe ice_sw nd_vis=0
sleep 1
modprobe ice_sw_ae
sleep 1
modprobe ies
sleep 1
modprobe hqm
sleep 1
modprobe adk_netd num_phy_ports=20 port_type=0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
sleep 1
ifconfig adketh4 204.204.204.1 up
sleep 1
/opt/adk/netd_uspace_lnk 4 1
sleep 1
ping 204.204.204.2 -c 5 -I adketh4 > /dev/null
/opt/adk/netd_if_stats 4
