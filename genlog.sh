#!/bin/bash
# log generator

timestamp() {
    echo $(date -u +%Y-%m-%dT%H:%M:%S.%NZ | sed -e 's/[0-9][0-9][0-9][0-9][0-9][0-9]Z/Z/' -e 's/%N/000/' )
}

_event ()
{
    printf "[%s] [EVENT] %s\n" `timestamp` "$*" >&2
}

_log ()
{
    echo "$MESSAGE"
}

_curl ()
{
	curl -v ${host_name} -d "$MESSAGE"
}

_curl_post ()
{
	curl -v -XPOST ${host_name} -d "$MESSAGE"
}

_info ()
{
    printf "$*\n" >&2
}

_randomize ()
{
    zrand=`expr ${RANDOM} % $1`
    zrand=`expr ${zrand} + 1`
    echo ${zrand}
}

_init_randomize ()
{
    SEED=`head -1 /dev/urandom | od -N 1 | awk '{ print $2 }'`
    export RANDOM=${SEED}
}

_loadresources ()
{
    test -f "/tmp/genlog_$$.resources.txt" || ls -1 "${profile_dir}/${profile_name}"/*.txt > /tmp/genlog_$$.resources.txt
    while read resource
    do
        rname=`basename ${resource} ".txt" | tr '-' '_'`
        eval "max_line=\${max_${rname}}"
        test -z "${max_line}" && max_line=`wc -l "${resource}" | sed 's/^[ \t]*//' | cut -d' ' -f1` && eval "export max_${rname}=\${max_line}"
        random_line=`_randomize ${max_line}`
        eval `sed -n -e "${random_line}p" -e "${random_line}q" "${resource}"`
    done < /tmp/genlog_$$.resources.txt
}

_on_init ()
{   # This function is called right before entering the main loop
    # It must be overloaded inside profile scripts
    return 0
}
_on_stop ()
{   # This function is called right after exiting the main loop
    # It must be overload inside profile scripts
    return 0
}
_on_log ()
{   # This function is called right before each raw log is fired.
    # It must be overloaded inside profile scripts
    return 0
}
_on_batch_full ()
{   # This function is called right after n raw logs are fired
    # It must be overload inside profile scripts
    return 0
}


TARGET=$0
initdir=`pwd`
if [ -L ${TARGET} ]
then
    LINK=`ls -l $0`
    TARGET=`echo ${LINK} |  sed 's/^.* -> //'`
    cd `dirname $0` && cd `dirname ${TARGET}`
else
    cd `dirname $0`
fi
curdir=`pwd`

log_dir="${curdir}"/logs
profile_dir="${curdir}"/profiles
default_max_message=5000
default_sleep_duration=0.5
default_profile_name="default"
randomize_batch_size=
test -d "${log_dir}" || mkdir -p "${log_dir}"

while getopts hrm:t:b:p:e:l: flag; do
    case ${flag} in
        h)
            _info "usage: genlog.sh [-h] [-m <int_value>] [-t <decimal_value>] [-b <int_value> [-r]] [-p <profile>])"
            _info "  -m: Number of raw log to fire (Default is ${default_max_message})"
            _info "  -t: Sleep time between each raw log (Default is ${default_sleep_duration})"
            _info "  -b: batch size (default is none). Perform a special action each time the batch size is reached."
            _info "  -r: Randomize batch size ('b' is mandatory and its value will be the maximum random value)."
            _info "  -p: Profile name. Must match a directory name under resources (Default is ${default_profile_name})."
            _info "  -e: Elasticsearch Host where the log are be sended with the curl command line with -XPOST argument."
            _info "  -l: Logstash host where the log are be sended with the curl command to the LogsStash server."
            exit 0
            ;;
        m)  max_occurs=$OPTARG;;
        t)  sleep_duration=$OPTARG;;
        b)  batch_size=$OPTARG;;
        r)  randomize_batch_size=y;;
        p)  profile_name=$OPTARG;;
        e)  es_host_name=$OPTARG;;
        l)  ls_host_name=$OPTARG;;
    esac
done

_init_randomize

# Parameters check
test -z "${profile_name}"&& profile_name=${default_profile_name}
if [ -n "${profile_name}" -a ! -d "${profile_dir}/${profile_name}" ]
then
    _info "Error: profile '${profile_name}' doesn't exist."
    profile_name=
fi
if [ -n "${max_occurs}" ]
then
    param_occurs=`echo "${max_occurs}" | sed -n '/^[0-9]*$/p'`
    if [ "${param_occurs}" != "${max_occurs}" ]
    then
        _info "Warning: 'm' value wasn't an integer. Max message will be set with default value."
        max_occurs=""
    fi
fi
if [ -n "${sleep_duration}" ]
then
    param_occurs=`echo "${sleep_duration}" | sed -n '/^[0-9]*[.0-9][0-9]*$/p'`
    if [ "${param_occurs}" != "${sleep_duration}" ]
    then
        _info "Warning: 't' value wasn't a valid value. Sleep duration will be set with default value."
        sleep_duration=""
    fi
fi
if [ -n "${batch_size}" ]
then
    param_occurs=`echo "${batch_size}" | sed -n '/^[0-9]*$/p'`
    if [ "${param_occurs}" != "${batch_size}" ]
    then
        _info "Warning: 'b' value wasn't an integer. Batch treatment will be disabled."
        batch_size=""
    else
        if [ -z "${randomize_batch_size}" ]
        then
            current_batch_size=${batch_size}
        else
            current_batch_size=`_randomize ${batch_size}`
        fi
    fi
fi
if [ -n "${randomize_batch_size}" -a -z "${batch_size}" ]
then
    _info "Warning: 'r' parameter is set without a 'b' parameter. It will be ignored."
    randomize_batch_size=
fi

test -z "${profile_name}" && exit 1
test -z "${max_occurs}" && max_occurs=${default_max_message}
test -z "${sleep_duration}" && sleep_duration=${default_sleep_duration}

# Load profile
. "${profile_dir}/${profile_name}"/*.sh 2>/dev/null

_info "Info: Profile is ${profile_name}."
_info "Info: ${max_occurs} raw logs will be fired each ${sleep_duration} seconds/"
expected_duration=`awk "BEGIN{print ${max_occurs} * (${sleep_duration} + 0.05) - ${sleep_duration}}"`
_info "Info: Expected duration is ${expected_duration} seconds."

start_time=`date -u +%s`
(
_event "START genlog"

occur=0
batch_elt=0
_on_init
while [ ${occur} -lt ${max_occurs} ]
do
    batch_elt=`expr ${batch_elt} + 1`
    occur=`expr ${occur} + 1`
    wait
    TIMESTAMP=`timestamp`
    _on_log
    _loadresources
    _log
	if [ -n  "${ls_host_name}" ]
	then
		host_name=${ls_host_name}
		_curl
	fi
	if [ -n  "${es_host_name}" ]
	then
		host_name=${es_host_name}
		echo "sens to ${es_host_name} and ${host_name}"
		_curl_post
	fi
    test ${occur} -eq ${max_occurs} || sleep ${sleep_duration} & 
    if [ -n "${current_batch_size}" ]
    then
        if [ ${batch_elt} -ge ${current_batch_size} ]
        then
            _on_batch_full
            batch_elt=0
            test -n "${randomize_batch_size}" && current_batch_size=`_randomize ${batch_size}`
        fi
    fi
done
if [ -n "${current_batch_size}" -a ${batch_elt} -gt 0 ]
then
    _on_batch_full
fi
_on_stop
_event "STOP genlog"
) | tee "${log_dir}"/log.txt

end_time=`date -u +%s`
reel_duration=`expr ${end_time} - ${start_time}`
delta=`awk "BEGIN{print ${reel_duration} - ${expected_duration}}"`
_info "Info: Finish job in ${reel_duration} seconds. Delta with expected duration is ${delta} seconds."
rm -f /tmp/genlog_$$.*.txt
exit 0

