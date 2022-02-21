#!/usr/bin/env bash
VER="1.1"

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/mysql/bin:/root/bin

ENV=$(which env)
WHICH=$(${ENV} which which)
GREP=$(${WHICH} grep)
SED=$(${WHICH} sed)
AWK=$(${WHICH} awk)
ECHO=$(${WHICH} echo)
SH=$(${WHICH} sh)
TOUCH=$(${WHICH} touch)
MKDIR=$(${WHICH} mkdir)
RM=$(${WHICH} rm)
UNAME=$(${WHICH} uname)
IXSQLBACKUP=$(${WHICH} ixsqlbackup)
opts=0
OPTS=(DBHOST USERNAME PASSWORD DBNAMES DBEXCLUDE TABLEEXLUDE COMP QUIETROTA)

while getopts c:lsh locs
do
	case $locs in
		c)	
		    CONFPATH=$OPTARG && opts=$((${opts}+1))
		    ;;
		l)	
		    LOCKJOB=1 && opts=$((${opts}+1))
			;;
		s)  
		    SILENTERROR=1 && opts=$((${opts}+1))
			;;
		h)	
		    HELP=1 && opts=$((${opts}+1))
			;;
		?)	
		    ${ECHO} "excuse me?" 
			;;
	esac
done

help () {
${ECHO} -en "Usage:
\t $0 -c conf
\t takes conf path as argument. can be either a file or a folder containing multiple files \n
\t default configuration under /usr/local/etc/ixsqlbackup.conf.d/multimysqlbackup.conf \n
\t $0 -l  
\t binary switch // enables lock file creation \n
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

if [[ -s "${CONFPATH}" ]] ; then
	export MAILADDR
	for LINE in $(${GREP} -Ev "^#|^$" ${CONFPATH} | ${SED} 's# #%20%#g') ; do
		[[ $(${ECHO} ${LINE} | ${AWK} -F ";" '{print NF}') -ne ${#OPTS[@]} ]] && ${ECHO} "OH DOG PLS CHECK CONF $CONFPATH" && continue
                for ((i=1;i<=${#OPTS[@]};i++)) ; do
			if [[ ${i} == 1 ]] ; then
				eval export "${OPTS[i-1]}"="'$(${ECHO} ${LINE} | ${AWK} -F\; '{print $'$i'}' | ${AWK} -F: '{print $1}')'"
				export DBPORT=$(${ECHO} ${LINE} | ${AWK} -F\; '{print $'$i'}' | ${AWK} -F: '{print $2}')
				[[ ${DBHOST} == localhost && ${DBPORT} ]] && DBHOST="127.0.0.1"
				[[ ! ${DBPORT} ]] && DBPORT="3306"
				continue
			fi
			eval export "${OPTS[i-1]}"="'$(${ECHO} ${LINE} | ${AWK} -F\; '{print $'$i'}' | ${SED} 's#%20%# #g')'"
		done
		if [[ ! -f ${LOCK}/${DBHOST}.lock && ${LOCKJOB} == 1 ]] ; then
			[[ ! -d ${LOCK} ]] && ${MKDIR} -p ${LOCK}
			${TOUCH} ${LOCK}/${DBHOST}.lock
			${SH} -c "${IXSQLBACKUP}"
			${RM} -f ${LOCK}/${DBHOST}.lock
		elif [[ ${LOCKJOB} == 0 ]] ; then
			${SH} -c "${IXSQLBACKUP}"
		else
			${ECHO} "LOCKJOB is enabled and ${LOCK}/${DBHOST}.lock file  was found, please check! Script skips backup for host: ${DBHOST}"
			exit 2
		fi
	done
	else
	if [[ ${SILENTERROR} == 0 ]] ; then
		${ECHO} "Config file not found: ${CONFPATH} (skipping)"
	fi
fi
