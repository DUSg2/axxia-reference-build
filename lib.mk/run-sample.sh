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
		-s	RDK sample to run (datapath, cryptolookaside, cryptoinline, portsetmode)

EOF
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

mount_hugepages()
{
mkdir -p /mnt/hugepages
mount -t hugetlbfs nodev /mnt/hugepages
echo 256 > /proc/sys/vm/nr_hugepages
}

run_datapath() 
{	
	# Testcase setup
	drivers=("uio" "ice_sw" "ice_sw_ae" "ies" "hqm")
	for i in "${drivers[@]}"
	do
	    load_driver $i
	    sleep 1
	done
	echo "[Info] starting data_path_sample_multiFlow sample"
	sleep 5
	/opt/rdk-samples/data_path_sample_multiFlow -n 4 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21,tx_mode=advanced,cmpltnq=1 --vdev=event_ihqm --lcores '(0-4)@0' -- -t 1 -p 0=10G
}

run_crypto_inline()
{
	echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
	drivers=("ice_sw" "ice_sw_ae" "ies" "hqm" "uio" "authenc" "dh_generic" "crc8" "intel_qat" "qat_c4xxx" "usdm_drv")
	for i in "${drivers[@]}"
	do
    		load_driver $i
    		sleep 1
	done
	adf_ctl down
	adf_ctl up
	load_driver ipsec_inline type=1
	echo "[Info] starting crypto_inline sample"
	sleep 5
	/opt/rdk-samples/crypto_inline -n 4 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21,ipsec_enable=1 --lcores '(0-4)@0' -- -t 1
}

run_crypto_lookaside()
{
	echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
	drivers=("ice_sw" "ice_sw_ae" "ies" "hqm" "uio" "authenc" "dh_generic" "crc8" "intel_qat" "qat_c4xxx" "usdm_drv")
	for i in "${drivers[@]}"
        do
            load_driver $i
            sleep 1
        done
	
	adf_ctl down
	adf_ctl up
	
	lspci -n | grep 18a0 || { echo "can't find qat device" && exit 1 ; }
		
	bus=$( lspci -n | grep 18a0 | cut -b 1-2 )
	device=$( lspci -n | grep 18a0 | cut -b 4-5 )
	function=$( lspci -n | grep 18a0 | cut -b 7 )

	pci_sysfs=$( find /sys/devices/ -name "*$bus\:$device\.$function*" )
	
	echo 2 > $pci_sysfs/sriov_numvfs
	insmod /opt/dpdk/kmod/igb_uio.ko
	ln -sf /usr/sbin/lspci /usr/bin/lspci
	/opt/dpdk/usertools/dpdk-devbind.py -b igb_uio $bus:00.1 $bus:00.2 $bus:00.3 $bus:00.4 $bus:00.5 $bus:00.6 $bus:00.7 $bus:01.0 $bus:01.1 $bus:01.2
	echo "[Info] starting crypto_lookaside sample"
	sleep 5
	/opt/rdk-samples/crypto_lookaside -n 4 -w 0000:$bus:$device.1 -w 0000:$bus:$device.2 -w 0000:$bus:$device.3 -w 0000:$bus:$device.4 -w 0000:$bus:$device.5 -w 0000:$bus:$device.6 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21 --vdev=event_ihqm --lcores '(0-4)@0' -- -t 21 -p 6
	/opt/rdk-samples/crypto_lookaside -n 4 -w 0000:$bus:$device.1 -w 0000:$bus:$device.2 -w 0000:$bus:$device.3 -w 0000:$bus:$device.4 -w 0000:$bus:$device.5 -w 0000:$bus:$device.6 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21 --vdev=event_ihqm --lcores '(0-4)@0' -- -t 13 -c 1 -p 0=10G -p 1=10G -p 2=10G -p 3=10G -p 4=10G -p 5=10G -p 6=10G -p 7=10G -p 8=10G -p 9=10G -p 10=10G -p 11=10G

}

run_portsetmode()
{
	drivers=("ice_sw" "ice_sw_ae" "ies" "hqm")
	for i in "${drivers[@]}"
	do
	    load_driver $i
	    sleep 1
	done
	echo "[Info] starting snrPortSetMode sample"
	sleep 5
	/opt/rdk-samples/snrPortSetMode -p 10 -s IES_PORT_MODE_ADMIN_PWRDOWN -t 1 -z 1
	
}

if [ -z $1 ] ; then \
	help
fi

# Parse arguments
unset OPTIND OPTION OPTARG
while getopts 's:h' OPTION; do
	     case ${OPTION} in
	         s) if [ ! -d /mnt/hugepages ] ; then \
			mount_hugepages
		    fi
			SAMPLE=${OPTARG};;
	         h) help;;
	     esac
done

case ${SAMPLE} in
	datapath) run_datapath;;
	cryptoinline) run_crypto_inline;;
	cryptolookaside) run_crypto_lookaside;;
	portsetmode) run_portsetmode;;
esac

