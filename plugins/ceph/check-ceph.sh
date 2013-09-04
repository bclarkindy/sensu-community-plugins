#!/bin/bash
#
# Check the health status of a ceph cluster
#
set -e

verbose=0
timeout=10
usage() {
cat <<EOF
Usage: ${0##*/} [-h] [-k KEYFILE] [-m MON_IP] [-t TIMEOUT] [-v[v]]
    Check health of ceph cluster
    Options:
        -k KEYFILE      Optional name of cephx authentication keyring file
        -m MONITOR_IP   Optional monitor ip
        -t TIMEOUT      Optional timeout in seconds (default=10s)
        -v              Run 'ceph health detail' command instead of 'ceph health'
        -vv             Additionally run 'ceph osd tree' commmand if not HEALTH_OK
EOF
}

while getopts ":hm:k:vt:" opt; do
    case $opt in
        m)
            cmd_args="${cmd_args} -m ${OPTARG}"
            ;;
        k)
            cmd_args="${cmd_args} -k ${OPTARG}"
            ;;
        h)
            echo "$(usage)" >&2
            exit 1
            ;;
        v)
            verbose=$((verbose+1))
            if [ "$verbose" -gt "2" ]; then verbose=2; fi
            ;;
        t)
            echo ${OPTARG} | grep -q "^-\?[0-9]*$" || { echo "${0##*/}: ${OPTARG} must be an integer" >&2; exit 1; }
            if [ "${OPTARG}" -eq "0" ]; then
                echo "${0##*/}: Timout should be non-zero to prevent command from hanging." >&2
                exit 1
            fi
            timeout=${OPTARG}
            ;;
        \?)
            echo "${0##*/}: Invalid option -${OPTARG}" >&2
            exit 1
            ;;
        :)
            echo "${0##*/}: -${OPTARG} requires an argument" >&2
            exit 1
            ;;
    esac
done

if [ "$timeout" -gt "0" ]; then timeout_cmd="timeout ${timeout}s "; fi

if [ $verbose -eq 0 ]; then
    cmd="${timeout_cmd}ceph health${cmd_args}"
else
    cmd="${timeout_cmd}ceph health detail${cmd_args}"
fi

set +e
#result=$(eval "${cmd}" 2>&1) || { if [ $verbose -gt "0" ]; then echo "$result"; fi; exit $UNKNOWN; }
result=$(eval "${cmd}" 2>&1)
ret_code=$?
set -e

# Handle timeout error; assuming ceph won't use 124 but timeout will
if [ $ret_code -eq 124 ]; then
    if [ $verbose -eq 0 ]; then
        echo "CRITICAL: Timeout occurred"
    else
        echo "CRITICAL: Timeout occurred with command '${cmd}'"
    fi
    if [ $verbose -gt 1 ]; then echo "${result}"; fi
    exit 2
fi

if [[ $result = *HEALTH_OK* ]]; then
    summary='HEALTH_OK'
    exit_status=0
elif [[ $result = "HEALTH_WARN noscrub,nodeep-scrub flag(s) set"* ]]; then
    summary="HEALTH_WARN noscrub,nodeep-scrub flag(s) set"
    exit_status=0
elif [[ $result = *HEALTH_WARN* ]]; then
    summary='HEALTH_WARN'
    exit_status=1
elif [[ $result = *HEALTH_ERR* ]]; then
    summary='HEALTH_ERR'
    exit_status=2
else
    summary='UNKNOWN'
    exit_status=3
fi

if [ $verbose -eq 0 ]; then
    echo "$summary"
else
    echo "${result}"
fi

# Run ceph osd tree command if necessary
if [ $verbose -eq 2 -a $exit_status -gt 0 ]; then
    cmd="${timeout_cmd}ceph osd tree${cmd_args}"
    result=$(eval "${cmd}" 2>&1)
    ret_code=$?
    if [ $ret_code -eq 124 ]; then
        echo "Timeout occured with command '${cmd}'"
        exit $exit_status
    fi
    echo "${result}"
fi

exit $exit_status
