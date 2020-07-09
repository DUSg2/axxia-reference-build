#!/bin/bash
## Uncomment for really verbose debugging, and be sure to uncomment the
## corresponding line at the end
#set -x -

mkdir -p ./logs
filestamp=./logs/$$_$(date +"%Y%m%d-%H%M")
logfile=$filestamp.log
summaryfile=$filestamp.summary

# SNR seems to reboot at around 1m55s loops, so set it to 2m30s to 
# give some margin...
MAX_REBOOT_TIME=150
MAX_TRYOUTS=3

export STOP=${STOP:-}
export CONTINUE=${CONTINUE:-}
TIMEFORMAT="%2lR"

args="$(getopt -n "$0" -l \
    help,stop,continue hxc $*)" \
|| exit -1
for arg in $args; do
    case "$arg" in
        -h)
            echo "$0 [-vxc]" \
                "[--verbose] [--stop] [--continue]"
            echo "`sed 's/./ /g' <<< "$0"` [-h] [--help]"
            exit 0;;
        --help)
            cat <<EOF
Usage: $0 [options] <target vlm_name>
Reboot tests for SNR

Options:
  -x, --stop       stop running tests after the first failure
  -c, --continue   do not exit, continue testing until user input
  -h,              show brief usage information and exit
  --help           show this help message and exit
EOF
            exit 0;;
        -x|--stop)
            STOP=1;;
        -c|--continue)
            CONTINUE=1;;
    esac
done

if [ $# -gt 1 ]; then
    shift
fi

if [ -z $@ ] ; then
    echo "you need to specify a target name. Eg. vlm_snr1"
    exit
fi

# check if helper docker container has been builded
is_built="$(docker images | grep "nfs-mount-test" -c)"
if [ 0 -eq $is_built ]; then
    echo "helper docker container is not in the available images"
    echo "follow instructions from examples/nfs_docker/README.txt"
    exit
fi

_indent=$'\n\t' # local format helper

target_shell="$(make -C . TARGET=$@ print-SSH_CMD | grep SSH_CMD | sed 's/^SSH_CMD = @//')"
target_ip="$(make -C . TARGET=$@ print-SSH_IP | grep SSH_IP | sed 's/^SSH_IP = //')"
target_vlmid="$(make -C . TARGET=$@ print-VLM_ID | grep VLM_ID | sed 's/^VLM_ID = //')"
cpu=$($target_shell -C dmidecode -t processor 2>/dev/null | grep ID | sed 's/\t\+ID://')
bios=$($target_shell -C dmidecode -s bios-version 2>/dev/null)
kernel=$($target_shell -C uname -a 2>/dev/null)
os=$($target_shell -C cat /etc/os-release 2>/dev/null | grep VERSION | head -1)

trap _shutdown EXIT

_shutdown()
{
    end_time="$(date +%s%N)"
    # required visible decimal place for seconds (leading zeros if needed)
    local test_time="$( \
        printf "%010d" "$(( ${end_time/%N/000000000}
                            - ${start_time/%N/000000000} ))")"  # in ns
    # to get report_time split tests_time on 2 substrings:
    #   ${test_time:0:${#test_time}-9} - seconds
    #   ${test_time:${#test_time}-9:3} - milliseconds
    local reboot_time="$( \
        printf "%010d" "$(( ${_reboot_time/%N/000000000} ))" )"  # in ns
    report_time="in ${test_time:0:${#test_time}-9}.${test_time:${#test_time}-9:3}s"
    (
        echo $_indent
        echo "CPU revision${_indent} ${cpu}"
        echo "BIOS version${_indent} ${bios}"
        echo "Kernel version${_indent} ${kernel}"
        echo "OS${_indent} ${os}"
        echo "${reboots_ok} successful reboot(s)"
        echo "${reboots_failed} failed reboot(s)"
        echo "in $report_time"
        echo "with an average reboot time of $cma_reboot_time (s)"
    ) | tee $summaryfile
    echo "parse ${logfile} for more details"  >> $summaryfile
    echo "done, review ${logfile} and ${summaryfile}"

}

issue_reboot()
{
    local start=`date +%s`
    # redirect all the following outputs to dev/null
    exec 2>/dev/null
    local res=1
    ping -q -c 1 -w 3 $target_ip > /dev/null 2>&1
    if [ 0 -eq $? ]; then
        $target_shell -C reboot
        local PING=0 # we wait for the target to stop responding to ping
        # signaling that it's actually rebooting
        TIMEOUT=0; while [ 0 -eq $PING ] && [ $TIMEOUT -lt $MAX_REBOOT_TIME ] ; do
            ping -q -c 1 -w 1 $target_ip > /dev/null 2>&1
            PING=$?
            TIMEOUT=$((TIMEOUT+5))
            echo -n "."
            sleep 5
        done
        local SSH=255 # we wait for the target to start responding to connections
        # signaling that it's actually rebooted
        TIMEOUT=0; while [ 255 -eq $SSH ] && [ $TIMEOUT -lt 120 ] ; do
            $target_shell -o ConnectTimeout=3 -C echo
            SSH=$?
            TIMEOUT=$((TIMEOUT+5))
            echo -n "."
            sleep 5
        done
        # sometimes the target is rebooted, but ssh is still not accepting connections
        # so the next connection timeout is longer, just to make sure we get a valid answer.
        $target_shell -o ConnectTimeout=10 -C echo
        res=$? # we did a reboot loop ?
    fi
    stop=`date +%s`
    reboot_time=$((stop-start))
    if [ 0 -eq $res ]; then
        # we update the cma reboot
        cma_reboot_time=$(((reboot_time + ((reboots_ok * cma_reboot_time))) / ((reboots_ok + 1))))
        echo $cma_reboot_time
    fi
    return $res
}

check_nfs()
{
    # worst case scenario, an exit code other than 0
    docker run --privileged=true --net=host nfs-mount-test -e TARGET="vlm-boards/$target_vlmid/rootfs"
}

loop=0
reboots_ok=0
reboots_failed=0
tryouts=$MAX_TRYOUTS
start_time="$(date +%s%N)" # nanoseconds_since_epoch
reboot_time=0 # last reboot time
cma_reboot_time=0 # cumulative moving average reboot time

while :
do
    loop=$((loop + 1))
    timestamp=$$_$( date --rfc-3339='seconds')
    echo "Reboot attempt $loop (ok: $reboots_ok failed: $reboots_failed)"
    nfs_status=$(check_nfs)
    time issue_reboot 2>&1
    if [ $? -eq 0 ]; then
        reboots_ok=$((reboots_ok + 1))
        (
            echo "$timestamp $@ $loop $((tryouts - MAX_TRYOUTS)) $reboots_ok $reboot_time $nfs_status reboot successful"
        ) | tee -a $logfile
        tryouts=$MAX_TRYOUTS # we reset our fault counter
    else
        reboots_failed=$((reboots_failed + 1))
        make -C .. TARGET=$@ vlm-restart-target
        sleep $MAX_REBOOT_TIME
        if [[ -n "$CONTINUE" ]]; then
            echo -n "!"
        else
            tryouts=$((tryouts - 1))
        fi
    fi
    if [[ -n "$STOP" ]] ; then
        if [ $tryouts -eq 2 ]; then
            (
                echo "$timestamp $@ $loop $((tryouts - MAX_TRYOUTS)) $reboots_ok $reboot_time $nfs_status reboot failed"
            ) | tee -a $logfile
            exit
        fi
    fi
    if [ $tryouts -eq 0 ]; then
        echo "reboot loop failed 3 times in a row. Closing test loop"
        exit
    fi
    sleep 5
done

## If debugging was enabled at the top, make sure it's off when we return
## to a normal shell:
#set +x
