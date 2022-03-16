#!/usr/bin/env bash
# comfy-wrapper.sh
# wrapper for improved-succotash
# VER 2.0
# Upstream URL: https://github.com/sandravwc/improved-succotash
#
#set -x
VER="2.0"
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/mysql/bin:/root/bin
ENV=$(which env)
WHICH=$(${ENV} which which)
GREP=$(${WHICH} grep)
AWK=$(${WHICH} awk)
ECHO=$(${WHICH} echo)
SH=$(${WHICH} sh)
TOUCH=$(${WHICH} touch)
MKDIR=$(${WHICH} mkdir)
RM=$(${WHICH} rm)
UNAME=$(${WHICH} uname)
SUCCOTASH=$(${WHICH} succotash)
opts=0
OPTS=(DBHOST USERNAME PASSWORD DBNAMES DBEXCLUDE TABLEEXLUDE COMP QUIETROTA)

op1 () {
    opts=$((opts+1))
}

while getopts c:lshd input
do
    case "${input}" in
        c) CONFPATH=$OPTARG && op1 ;;
        l) LOCKJOB=1 && op1 ;;
        s) SILENTERROR=1 && op1 ;;
        h) HELP=1 && op1 ;;
        d) DEBUG=1 && op1 ;;
        ?) ${ECHO} "excuse me?" ;;
    esac
done

[[ ${DEBUG} == 1 ]] && set -x

help () {
${ECHO} -en "Usage:
\t $0 -c conf
\t takes conf path as argument. can be either a file or a folder containing multiple files \n
\t default configuration under /usr/local/etc/ixsqlbackup.conf.d/multimysqlbackup.conf \n
\t $0 -l  
\t binary switch // enables lock file creation \n
\t $0 -a
\t binary switch // enables plesk db auto detection \n
\t $0 -s
\t binary swich // disables error reports from multimysqlbackup \n
\t $0 -h
\t show this dialog 
\t Example: $0 -c /etc/multimysqlbackup.conf -la \n"
    exit 0
}

[[ ${HELP} == 1 ]] && help
[[ ! ${CONFPATH} ]] && CONFPATH=/usr/local/etc/ixsqlbackup.conf.d/multimysqlbackup.conf
[[ ! ${LOCKJOB} ]] && LOCKJOB=0
[[ ! ${SILENTERROR} ]] && SILENTERROR=0

if [[ ! $(${UNAME} -o | ${GREP} -i linux) ]] ; then
    LOCK=/usr/local/var/lock
elif [[ $(${UNAME} -o | ${GREP} -i linux) ]] ; then
    LOCK=/var/lock
else
    ${ECHO} "bro check uname -o output"
fi

####

if [[ -s "${CONFPATH}" ]]
then
    IFS=$'\n'
    export MAILADDR
    for LINE in $(${GREP} -Ev "^#|^$" ${CONFPATH})
    do
        if [[ $(${ECHO} "${LINE}" | ${AWK} -F ";" '{print NF}') -ne ${#OPTS[@]} ]]
        then
            ${ECHO} "OH DOG PLS CHECK CONF ${CONFPATH}" 
            continue
        fi
        for ((i=1;i<=${#OPTS[@]};i++))
        do
            if [[ "${i}" == 1 ]]
            then
                # shellcheck disable=2086,2016
                eval export "${OPTS[i-1]}"="'$(${ECHO} "${LINE}" \
                    | ${AWK} -F\; '{print $'$i'}' \
                    | ${AWK} -F: '{print $1}'\
                )'"
                # shellcheck disable=2086,2016,2155
                export DBPORT=$(${ECHO} "${LINE}" \
                    | ${AWK} -F\; '{print $'$i'}' \
                    | ${AWK} -F: '{print $2}'\
                )
                [[ ${DBHOST} == localhost && ${DBPORT} ]] && DBHOST="127.0.0.1"
                [[ ! ${DBPORT} ]] && DBPORT="3306"
                continue
            fi
            #shellcheck disable=2086
            eval export "${OPTS[i-1]}"="'$(${ECHO} "${LINE}" | ${AWK} -F\; '{print $'$i'}')'"
        done
        if [[ ! -f ${LOCK}/${DBHOST}.lock && ${LOCKJOB} == 1 ]]
        then
            [[ ! -d ${LOCK} ]] && ${MKDIR} -p ${LOCK}
            ${TOUCH} ${LOCK}/${DBHOST}.lock
            ${SH} -c "${SUCCOTASH}"
            ${RM} -f ${LOCK}/${DBHOST}.lock
        elif [[ ${LOCKJOB} == 0 ]]
        then
            ${SH} -c "${SUCCOTASH}"
        else
            ${ECHO} "LOCKJOB is enabled and ${LOCK}/${DBHOST}.lock file  was found, please check! Script skips backup for host: ${DBHOST}"
            exit 2
        fi
    done
    else
    if [[ ${SILENTERROR} == 0 ]]
	then
        ${ECHO} "Config file not found: ${CONFPATH} (skipping)"
    fi
fi