#!/bin/bash

help()
{
	cat <<-EOF
	
	This is a helper script for RDK samples
	setup and testing.
	
	Usage:
	
		$0 [-h] [-s]
	
	Arguments:
	
		-h	Print this help
		-s	RDK sample to run (datapath, cryptolookaside, cryptoinline)

EOF
}

check_sku()
{
  SKUVAL=$(setpci -d 8086:18a0 0x354.l)
  if [ $SKUVAL = "00000000" ]; then
    rv="high"
  elif [ $SKUVAL = "f000f000" ]; then
    rv="medium"
  elif [ $SKUVAL = "ffc0ffc0" ]; then
    rv="low"
  fi
    echo $rv
}

load_driver()
{
    DRIVER=$1
    ARGUMENTS=$2
    RC=0
    lsmod | grep $DRIVER || RC=$?
    if [ $RC -ne 0 ]; then
        RC=0
        modprobe $DRIVER $ARGUMENTS 2>>/dev/null || RC=$?
    fi
    if [ $RC -ne 0 ]; then
        echo "Driver $DRIVER failed to load"
    fi
}

tear_down()
{
	#UnLoad drivers
	echo "Unloading Drivers:....."
	sleep 5
	drivers=("adk_netd" "ice_sw_ae" "ies" "ipsec_inline" "ice_sw" "hqm"
								"qat_c4xxx" "usdm_drv" "intel_qat")
	for i in "${drivers[@]}"; do
	    remove_driver $i
	done
}

init_hugepages()
{
        # If hugepages are not setup, set them up.
        hugepagecount=1024
        hugemount=$(mount | awk '/hugetlbfs/{print $3}')
        num_huge_pages=$(cat /proc/sys/vm/nr_hugepages)
        if [ -z "$hugemount" -o $num_huge_pages -lt $hugepagecount ]; then
            mkdir -p /mnt/hugepages
            mount -t hugetlbfs nodev /mnt/hugepages
            echo $hugepagecount > /proc/sys/vm/nr_hugepages

            echo "Setting up hugepages"
            freehp=`cat /proc/meminfo | awk '/HugePages_Total/ {print $2}'`
            if [ $freehp -ne $hugepagecount ]; then
                echo "Hugepage set up failed!"
                exit 1
            else
                echo "Hugepage set successful!"
            fi
        fi
}

driver_init_dsi()
{
	#Load drivers if not loaded already
	echo "Loading Drivers:....."
	drivers=("uio" "ice_sw nd_vis=0" "ice_sw_ae" "ies" "hqm" "adk_netd netlink_mode=0")
	for i in "${drivers[@]}"
	do
		load_driver $i
	done

	# Sleep to workaround CSSY-1300, delay in binding IES to CPK.
	sleep 5

	lsmod
}

driver_init_inline()
{
        #Load drivers if not loaded already
        echo "Loading Drivers:....."
        drivers=("uio" "ice_sw nd_vis=0" "ice_sw_ae" "ies" "hqm" "adk_netd netlink_mode=0")
        for i in "${drivers[@]}"
        do
                load_driver $i
        done

        # Sleep to workaround CSSY-1300, delay in binding IES to CPK.
        sleep 5
        declare -A SKUMAP_QATCONF
        SKUMAP_QATCONF=([high]=./c4xxx_dev0.conf.sym.inline
                        [medium]=./c4xxx_dev0.conf.sym.inline.med
                        [low]=./c4xxx_dev0.conf.sym.inline.low)

        CONF_DIR=/etc

        modprobe authenc
        modprobe dh_generic
        modprobe crc8

        qat_drivers=("intel_qat" "qat_c4xxx")
        for i in "${qat_drivers[@]}"
        do
                load_driver $i
        done

        SKUVAL=$(check_sku)
        echo "SKUVAL::$SKUVAL, ${SKUMAP_QATCONF[$SKUVAL]}"
        CONF_FILE=${CONF_DIR}/${SKUMAP_QATCONF[$SKUVAL]}
        if [ ! -f ${CONF_FILE} ]; then
                echo "Error: Unable to find ${CONF_FILE}"
        fi

        adf_ctl down
        adf_ctl -c ${CONF_FILE} up

        load_driver usdm_drv
        load_driver ipsec_inline type=1

        lsmod
}

run_datapath() 
{	
	# Testcase setup
	init_hugepages
	
	drivers=("uio" "ice_sw nd_vis=0" "ice_sw_ae" "ies" "hqm" "adk_netd netlink_mode=0")
	for i in "${drivers[@]}"
	do
	    load_driver $i
	    sleep 1
	done
	
	echo "[Info] starting data_path_sample_multiFlow sample"
	sleep 5
	/opt/rdk-samples/data_path_sample_multiFlow -n 2 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21,tx_mode=advanced,cmpltnq=1,drbellq=1,extq_enable=1 --vdev=event_ihqm --lcores '(0-4)@0' --proc-type=primary -- -t 1 -p 0=10G
}

run_crypto_inline()
{
	# Mount huge pages.
	init_hugepages
	
	drivers=("uio" "authenc" "dh_generic" "crc8" "ice_sw nd_vis=0" "ice_sw_ae" "ies" "hqm" "adk_netd netlink_mode=0")
	for i in "${drivers[@]}"
	do
    		load_driver $i
    		sleep 1
	done
	
	declare -A SKUMAP_QATCONF
	SKUMAP_QATCONF=([high]=./c4xxx_dev0.conf.sym.inline
                [medium]=./c4xxx_dev0.conf.sym.inline.med
                [low]=./c4xxx_dev0.conf.sym.inline.low)
	sleep 5
	
	qat_drivers=("intel_qat" "qat_c4xxx" "usdm_drv")
	for i in "${qat_drivers[@]}"
	do
		load_driver $i
		sleep 1
	done
	
	SKUVAL=$(check_sku)
	CONF_DIR=/etc
	echo "SKUVAL::$SKUVAL, ${SKUMAP_QATCONF[$SKUVAL]}"
	CONF_FILE=${CONF_DIR}/${SKUMAP_QATCONF[$SKUVAL]}
	if [ ! -f ${CONF_FILE} ]; then
		echo "Error: Unable to find ${CONF_FILE}"
	fi
	
	adf_ctl down
	adf_ctl -c ${CONF_FILE} up
	load_driver ipsec_inline type=1
	lsmod
	
	bdf_number=$(lspci -D -vnd 8086:1896 | awk 'NR==1 {print $1}')
	echo "bdf_number = $bdf_number"
	
	echo "[Info] starting crypto_inline sample"
	sleep 5
	/opt/rdk-samples/crypto_inline -n 2 --vdev=net_ice_dsi0,pci-bdf=${bdf_number},rxq=21,txq=21,ipsec_enable=1 --lcores '(0-4)@0' -- -t 1 -p 0=10G
}

run_crypto_lookaside()
{	
	init_hugepages
	
	device_id=18a0
	drivers=("uio" "authenc" "dh_generic" "crc8" "uio_pci_generic" "ice_sw nd_vis=0" "ice_sw_ae" "ies" "hqm" "adk_netd netlink_mode=0")
	for i in "${drivers[@]}"
        do
            load_driver $i
            sleep 1
        done
	sleep 5
	
	declare -A SKUMAP_QATCONF
	SKUMAP_QATCONF=([high]=./c4xxx_dev0.conf.inline
                [medium]=./c4xxx_dev0.conf.inline.med
                [low]=./c4xxx_dev0.conf.inline.low)
    
	CONF_DIR=/etc
    
	qat_drivers=("intel_qat" "qat_c4xxx" "usdm_drv")
	for i in "${qat_drivers[@]}"
	do
		load_driver $i
		sleep 1
	done
	
	SKUVAL=$(check_sku)
	echo "SKUVAL::$SKUVAL, ${SKUMAP_QATCONF[$SKUVAL]}"

	CONF_FILE=${CONF_DIR}/${SKUMAP_QATCONF[$SKUVAL]}
	if [ ! -f ${CONF_FILE} ]; then
		echo "Error: Unable to find ${CONF_FILE}"
	fi

	adf_ctl down
	adf_ctl -c ${CONF_FILE} up
	
	ln -sf /usr/sbin/lspci /usr/bin/lspci

	#Get pci-bdf for qat device
	lspci -n | grep $device_id || { echo "can't find qat device" && exit 1; }

	bus=$( lspci -n | grep $device_id | cut -b 1-2 )
	device=$( lspci -n | grep $device_id | cut -b 4-5 )
	function=$( lspci -n | grep $device_id | cut -b 7 )

	pci_sysfs=$( find /sys/devices/ -name "*$bus\:$device\.$function*" )

	cd $pci_sysfs
	cat sriov_numvfs; echo 2 > sriov_numvfs
	lsmod
	
	/opt/dpdk/usertools/dpdk-devbind.py -b uio_pci_generic $bus:00.1 $bus:00.2 $bus:00.3 $bus:00.4 $bus:00.5 $bus:00.6 $bus:00.7 $bus:01.0 $bus:01.1 $bus:01.2
	
	echo "[Info] starting crypto_lookaside sample"
	sleep 5

	/opt/rdk-samples/crypto_lookaside -n 2 -w 0000:$bus:$device.1 -w 0000:$bus:$device.2 -w 0000:$bus:$device.3 -w 0000:$bus:$device.4 -w 0000:$bus:$device.5 -w 0000:$bus:$device.6 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21 --vdev=event_ihqm --lcores '(0-4)@0' -- -t 13 -c 1 -p 0=10G -p 1=10G -p 2=10G -p 3=10G -p 4=10G -p 5=10G -p 6=10G -p 7=10G -p 8=10G -p 9=10G -p 10=10G -p 11=10G

}

run_cpu_dsi_lpbk()
{	
	init_hugepages
	tear_down
	
	TEST_STATUS=0

	echo ""
	echo "============================"
	echo "Starting CPU DSI PKT Test"
	echo "============================"
	echo ""

	driver_init_dsi

	sleep 5

	/opt/rdk-samples/cpu_dsi_lpbk -n 4 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21,tx_mode=advanced,cmpltnq=1 --vdev=event_ihqm -- -p /opt/rdk-samples/cpu_dsi_traffic.pcap -t 60

	if [ $? -eq 0 ]; then
		echo "CPU DSI Traffic Loopback Test Passed"
	else
		TEST_STATUS=1
		echo "CPU DSI Traffic Loopback Test Failed"
	fi

	tear_down
	exit $TEST_STATUS
}

run_cpu_inline_lpbk()
{
	init_hugepages

	tear_down

	TEST_STATUS=0

	echo ""
	echo "============================"
	echo "Starting Packet Encrypt Test"
	echo "============================"
	echo ""

	driver_init_inline
		
	sleep 5
	
	/opt/rdk-samples/cpu_inline_lpbk -n 4 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21,tx_mode=advanced,cmpltnq=1,ipsec_enable=1 --vdev=event_ihqm -- -p /opt/rdk-samples/plaintxt.pcap -t 60  -e -r /opt/rdk-samples/ipsec.pcap
	
	if [ $? -eq 0 ]; then
        echo "Inline Encrypt Traffic Loopback Test Passed"
	else
        TEST_STATUS=1
        echo "Inline Encrypt Traffic Loopback Test Failed"
	fi
	
	sleep 5
	
	tear_down
	sleep 5
	
	echo ""
	echo "============================"
	echo "Starting Packet Decrypt Test"
	echo "============================"
	echo ""

	driver_init_inline
	sleep 5
	
	/opt/rdk-samples/-n 4 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21,tx_mode=advanced,cmpltnq=1,ipsec_enable=1 --vdev=event_ihqm -- -p /opt/rdk-samples/ipsec.pcap -t 60 -r /opt/rdk-samples/plaintxt.pcap
	
	if [ $? -eq 0 ]; then
        echo "Inline Decrypt Traffic Loopback Test Passed"
	else
        TEST_STATUS=1
        echo "Inline Decrypt Traffic Loopback Test Failed"
	fi
	
	if [ $TEST_STATUS -eq 0 ]; then
        echo "Inline Traffic Loopback Test Passed"
        echo "Test QA Complete"
	else
        echo "Inline Traffic Loopback Test Failed"
        echo "Test QA Failure"
	fi

	tear_down
	exit $TEST_STATUS
}

if [ -z $1 ] ; then \
	help
fi

# Parse arguments
unset OPTIND OPTION OPTARG
while getopts 's:h' OPTION; do
	     case ${OPTION} in
	         s) SAMPLE=${OPTARG};;
	         h) help;;
	     esac
done

case ${SAMPLE} in
	datapath) run_datapath;;
	cryptoinline) run_crypto_inline;;
	cryptolookaside) run_crypto_lookaside;;
	cpudsilpbk) run_cpu_dsi_lpbk;;
	cpuinlinelpbk) run_cpu_inline_lpbk;;
esac

