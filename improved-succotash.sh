#!/usr/bin/env bash
# ixsqlbackup
# SQL Backup Script - MySQL and MariaDB
# VER 2.1
#
#################################################################
# based on                                                      #
#################################################################
# MySQL Backup Script                                           #
# VER. 2.6.8 - http://sourceforge.net/projects/automysqlbackup/ #
# Copyright (c) 2002-2003 wipe_out@lycos.co.uk                  #
#################################################################
#set -x

VER="2.1"

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/mysql/bin:/root/bin

ENV="$(which env)"
WHICH="$(${ENV} which which)"
ECHO="$(${WHICH} echo)"
CAT="$(${WHICH} cat)"
BASENAME="$(${WHICH} basename)"
DATEC="$(${WHICH} date)"
DU="$(${WHICH} du)"
FIND="$(${WHICH} find)"
RM="$(${WHICH} rm)"
MYSQL="$(${WHICH} mysql)"
MYSQLDUMP="$(${WHICH} mysqldump)"
GZIP="$(${WHICH} gzip)"
BZIP2="$(${WHICH} bzip2)"
HOSTNAMEC="$(${WHICH} hostname)"
SED="$(${WHICH} sed)"
GREP="$(${WHICH} grep)"
MKDIR="$(${WHICH} mkdir)"
NAIL="$(${WHICH} nail 2>/dev/null)"
SNAIL="$(${WHICH} s-nail 2>/dev/null)"
MUTT="$(${WHICH} mutt 2>/dev/null)"
MMAIL="$(${WHICH} mail 2>/dev/null)"
SMBIN="$(${WHICH} sendmail 2>/dev/null)"
READLINK="$(${WHICH} readlink 2>/dev/null)"

CONFIGFILE="/usr/local/etc/ixsqlbackup.conf.d/ixsqlbackup.conf"

if [[ -r ${CONFIGFILE} ]] ; then
	source ${CONFIGFILE}
else
	USERNAME=$(${ECHO} ${USERNAME:="dbuser"})
	
	# Password to access the MySQL server e.g. password
	PASSWORD=$(${ECHO} ${PASSWORD:="password"})
	# Host name (or IP address) of MySQL server e.g localhost
	DBHOST=$(${ECHO} ${DBHOST:="localhost"})
	# Port where MYSQL Server is listening
	DBPORT=$(${ECHO} ${DBPORT:="3306"})
	
	# List of DBNAMES for Daily/Weekly Backup e.g. "DB1 DB2 DB3"
	DBNAMES=$(${ECHO} ${DBNAMES:="DB1 DB2 DB3"})
	
    LOGDIR=$(${ECHO} ${LOGDIR:="/var/log/ixsqlbackup"})

	# Backup directory location e.g /backups
	BACKUPDIR=$(${ECHO} ${BACKUPDIR:="/backup/mysql/${DBHOST}"})
	# - log   : send only log file
	# - files : send log file and sql files as attachments (see docs)
	# - stdout : will simply output the log to the screen if run manually.
	# - quiet : Only send logs if an error occurs to the MAILADDR.
	MAILCONTENT="quiet"
	
	# Set the maximum allowed email size in k. (4000 = approx 5MB email)
	MAXATTSIZE="4000"
	
	# Email Address to send mail to? (user@domain.com)
	MAILADDR=$(${ECHO} ${MAILADDR:="maintenance@example.com"})
	
	# Email Address to send mail from? (root@host.tld)
	FROMADDR="ixsqlbackup@$(${HOSTNAMEC} -f)"
	
	# List of DBNAMES to EXLUCDE if DBNAMES are set to all (must be in " quotes)
	DBEXCLUDE=$(${ECHO} ${DBEXCLUDE:=""})
	
	# List of tables to exclude. Space-separated, with db name, e.g. "db1.table1 d2.table2"
	TABLEEXCLUDE=$(${ECHO} ${TABLEEXCLUDE:=""})

	# Include CREATE DATABASE in backup?
	CREATE_DATABASE=yes
	
	# Separate backup directory and file for each DB? (yes or no)
	SEPDIR=yes
	
	# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
	DOWEEKLY=6
	
	# Choose Compression type. (gzip or bzip2)
	COMP=$(${ECHO} ${COMP:="gzip"})

	# Use pipe compress
	PIPECOMP=no

	# Compress communications between backup server and MySQL server?
	COMMCOMP=no
	
	#  The maximum size of the buffer for client/server communication. e.g. 16MB (maximum is 1GB)
	MAX_ALLOWED_PACKET=
	
	#  For connections to localhost. Sometimes the Unix socket file must be specified.
	SOCKET=

	# Backup databases per table work if SEPDIR set to yes
	PERTABLE=yes

	# daily backup retention in days
	DROTA=7

	# weekly backup retention in weeks
	WROTA=5

	# monthly backup retention in months where 1 month equals 30 days
	MROTA=5
 
	# Command to run before backups (uncomment to use)
	PREBACKUP=$(${ECHO} ${PREBACKUP:="/etc/ixsqlbackup/mysql-backup-pre"})
	
	# Command run after backups (uncomment to use)
	POSTBACKUP=$(${ECHO} ${POSTBACKUP:="/etc/ixsqlbackup/mysql-backup-post"})

	# don't show messages about rotating backups
	QUIETROTA=$(${ECHO} ${QUIETROTA:="no"})

	# set 0 to skip mailcmd reverse-path-support so you dont need do fix pkg on your pdp11
	REVERSEPATH=$(${ECHO} ${REVERSEPATH:="1"})
fi


is_sendmail_qmail () {
	while [[ -L ${SMBIN} ]] ; do
		SMBIN=$(${READLINK} -e ${SMBIN} 2>/dev/null ) || {
			SMBIN=$(${READLINK} -f ${SMBIN})
		} 
	done
	if [[ ! $(${ECHO} ${SMBIN} | ${GREP} -i qmail) ]] ; then
		${ECHO} 0
	else
		${ECHO} 1
	fi
}

[[ ${SNAIL} ]] && MAILCMD=${SNAIL}
[[ ! ${MAILCMD} ]] && {
    [[ ${NAIL} ]] && MAILCMD=${NAIL}
}

[[ ! ${MAILCMD} ]] && {
    [[ ${MMAIL} ]] && {
        if [[  $(${MMAIL} -r 2>&1 | ${GREP} -E "(invalid|illegal) option -- r") ]] ; then
            [[ ${REVERSEPATH} == 0 ]] &&  {
			    MAILCMD=${MMAIL} 
			}
            [[ ${REVERSEPATH} == 1 ]] && { 
				${ECHO} "No mail command with RFC 5321 reverse-path support found. Install s-nail if on BSD"
            exit 1
			}
        else
            MAILCMD=${MMAIL}
        fi
    }
}

# sendmail replacement of qmail does not support -r option
if [[ $(is_sendmail_qmail) == 1 ]] ; then
	MAIL_BASE_CMD="${MAILCMD}"
else
	[[ ${REVERSEPATH} == 1 ]] && {
	    MAIL_BASE_CMD="${MAILCMD} -r ${FROMADDR}"
	}
    [[ ${REVERSEPATH} == 0 ]] && {
		MAIL_BASE_CMD="${MAILCMD}"
	}
fi

while [[ $# -gt 0 ]] ; do
	case ${1} in
		-c)
			if [[ -r ${2} ]] ; then
				source "${2}"
				shift 2
			else
				${ECHO} "Ureadable config file \"${2}\""
				exit 1
			fi
			;;
		*)
			${ECHO} "Unknown Option \"${1}\""
			exit 2
			;;
	esac
done

export LC_ALL=C
PROGNAME=$(${BASENAME} $0)
DATE=$(${DATEC} +%Y-%m-%d_%Hh%Mm)                           # Timestamp e.g 2002-09-21
DOW=$(${DATEC} +%A)                                         # Day of the week e.g. Monday
DNOW=$(${DATEC} +%u)                                        # Day number of the week 1 to 7 where 1 represents Monday
DOM=$(${DATEC} +%d)                                         # Date of the Month e.g. 27
DDOM=$((10#${DOM}))                                         # force decimal $DOM
LOGFILE="${LOGDIR}/${DBHOST}/${DATE}.log"                   # Logfile Name
LOGERR="${LOGDIR}/${DBHOST}/ERRORS_${DATE}.log"             # Logfile Name
BACKUPFILES=""
SUFFIX=""

if [[ ! $(${MYSQLDUMP} --events 2>&1 | ${GREP} "unknown option") ]] ; then
    OPT="\
	--events \
    --ignore-table=mysql.events \
	--quote-names \
	--opt \
	--single-transaction \
	--routines \
	--set-gtid-purged=OFF\
	"
else
    OPT="\
	--quote-names \
	--opt \
	--single-transaction \
	--routines \
	--set-gtid-purged=OFF\
	"
fi

[[ ! -d ${LOGDIR}/${DBHOST} ]] && ${MKDIR} -p ${LOGDIR}/${DBHOST}
touch ${LOGFILE}
touch ${LOGERR}

exec 6>&1
exec > ${LOGFILE}

exec 7>&2
exec 2> ${LOGERR}

skip_schema_opts () {
	case "${1}" in
		information_schema) 
			[[ ${OPT} =~ "--skip-lock-tables" ]] || OPT="${OPT} --skip-lock-tables"
			;;
		performance_schema) 
			[[ ${OPT} =~ "--skip-lock-tables --skip-events" ]] || OPT="${OPT} --skip-lock-tables --skip-events" 
			;;
		*)
		    [[ ${OPT} =~ "--skip-lock-tables" ]] && OPT=$(${ECHO} ${OPT} | ${SED} 's# --skip-lock-tables # #')
			[[ ${OPT} =~ "--skip-events" ]] && OPT=$(${ECHO} ${OPT} | ${SED} 's# --skip-events # #')
			;;
	esac
}

#### Functions
dbdump () {
	# param 1 == DB
	# param 2 == file to save
	skip_schema_opts "${1}"
	{ ${MYSQLDUMP} \
	--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  \
	--user=${USERNAME} \
	--host=${DBHOST} \
	--port=${DBPORT} ${OPT} ${1} > ${2} 
	}
	return $?
}

dbdump_comp () {
	# param 1 == DB
	# param 2 == file to save
	skip_schema_opts "${1}"
	case ${COMP} in
		gzip) 
			${ECHO} "Backup Information for ${1}.gz"
			SUFFIX=".gz"
			{ ${MYSQLDUMP} \
			--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  \
			--user=${USERNAME} \
			--host=${DBHOST} \
			--port=${DBPORT} ${OPT} ${1} \
			| ${GZIP} > ${2}${SUFFIX} 
			}
			${GZIP} -l "${1}.gz"
			;;
		bzip2)
			${ECHO} "Compression information for ${1}.bz2"
			SUFFIX=".bz2"
			{ ${MYSQLDUMP} \
			--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  \
			--user=${USERNAME} \
			--host=${DBHOST} \
			--port=${DBPORT} ${OPT} ${1} \
			| ${BZIP2} -v 2>&1 > ${2}${SUFFIX} 
			}
			;;
		*)	
			${ECHO} "No compression option set, check advanced settings"
			;;
	esac
	return $?	
}


dbdump_table () {
	# param 1 == DB
	# param 2 == TABLE
	# param 3 == file to save
	if [[ $(${ECHO} ${TABLEEXCLUDE} | ${GREP} "${1}.${2}") ]] ; then
		OPT=$(${ECHO} ${OPT} | ${SED} 's# --opt # --skip-opt #')
	fi
	skip_schema_opts "${1}"
	{ ${MYSQLDUMP} \
	--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  \
	--user=${USERNAME} \
	--host=${DBHOST} \
	--port=${DBPORT} ${OPT} ${1} ${2} > ${3}
	}
	return $?
}

dbdump_table_comp () {
	# param 1 == DB
	# param 2 == TABLE
	# param 3 == file to save

	if [[ $(${ECHO} ${TABLEEXCLUDE} | ${GREP} "${1}.${2}") ]] ; then
		OPT=$(${ECHO} ${OPT} | ${SED} 's# --opt # --skip-opt #')
	fi
	skip_schema_opts "${1}"
	case ${COMP} in
		gzip)
			${ECHO} "Backup Information for ${3}.gz"
			SUFFIX=".gz"
			{ ${MYSQLDUMP} \
			--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  \
			--user=${USERNAME} \
			--host=${DBHOST} \
			--port=${DBPORT} ${OPT} ${1} ${2} \
			| ${GZIP} > ${3}${SUFFIX}
			${GZIP} -l "${3}.gz" 
			}
			;;
		bzip2)
			${ECHO} "Compression information for ${3}.bz2"
			SUFFIX=".bz2"
			{ ${MYSQLDUMP} \
			--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  \
			--user=${USERNAME} \
			--host=${DBHOST} \
			--port=${DBPORT} ${OPT} ${1} ${2} | ${BZIP2} -v 2>&1 > ${3}${SUFFIX} 
			}
			;;
		*)
			${ECHO} "No compression option set, check advanced settings"
			;;
	esac
	return $?
}

compression () {
	case ${COMP} in
		gzip)
		    SUFFIX=".gz"
			${GZIP} -f "${1}"
			${ECHO} "Backup Information for ${1}.gz"
			${GZIP} -l "${1}.gz"
			
			;;
		bzip2)
		    SUFFIX=".bz2"
			${ECHO} "Compression information for ${1}.bz2"
			${BZIP2} -f -v ${1} 2>&1
			;;
		*)	
			${ECHO} "No compression option set, check advanced settings"
			;;
	esac
	return 0
}

rotate () {
	
	${FIND} "${BACKUPDIR}/${1}/${DB}_pertable" -mtime +${DROTA} -type f -exec ${RM} -v {} \;
	${FIND} ${BACKUPDIR} -name "*_pertable*" -type d -empty -delete	
}


rotate () {
	[[ ${QUIETROTA} = yes ]] || ${ECHO} "Rotating ${1} backups... "${TABLE}".sql"${SUFFIX}""
	case ${1} in
		daily)
			${FIND} "${BACKUPDIR}/${1}/${DB}_pertable/" -name ${TABLE}.sql${SUFFIX} -mtime +${DROTA} -type f -exec ${RM} -v {} \;
			[[ ${QUIETROTA} = yes ]] || {
			echo "${FIND} "${BACKUPDIR}/${1}/${DB}_pertable/" -name ${TABLE}.sql${SUFFIX} -mtime +${DROTA} -type f -exec ${RM} -v {} \;"
			}
			;;
		weekly)
		    ${FIND} "${BACKUPDIR}/${1}/${DB}_pertable/" -name ${TABLE}.sql${SUFFIX} -mtime +$((${WROTA}*7)) -type f -exec ${RM} -v {} \;
			[[ ${QUIETROTA} = yes ]] || {
			echo "${FIND} "${BACKUPDIR}/${1}/${DB}_pertable/" -name ${TABLE}.sql${SUFFIX} -mtime +$((${WROTA}*7)) -type f -exec ${RM} -v {} \;"
			}
			;;
		monthly)
		    ${FIND} "${BACKUPDIR}/${1}/${DB}_pertable/" -name ${TABLE}.sql${SUFFIX} -mtime +$((${MROTA}*30)) -type f -exec ${RM} -v {} \;
			[[ ${QUIETROTA} = yes ]] || {
			echo "${FIND} "${BACKUPDIR}/${1}/${DB}_pertable/" -name ${TABLE}.sql${SUFFIX} -mtime +$((${MROTA}*30)) -type f -exec ${RM} -v {} \;"
			}
			;;
	esac

	${FIND} ${BACKUPDIR} -name "*_pertable*" -type d -empty -delete	
}




sepdir () {
	for DB in ${DBNAMES}
	do

		DB="$(${ECHO} ${DB} | ${SED} 's#%# #g')"

		if [[ ${PERTABLE} == yes  ]] ;
		then # DB backup per table
			[[ ! -e "${BACKUPDIR}/${1}/${DB}_pertable" ]] && ${MKDIR} -p "${BACKUPDIR}/${1}/${DB}_pertable"
			${ECHO} "${1} Backup of ${DB} per table..."
			TABLES="$(${MYSQL} \
			--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD}) \
			--user=${USERNAME} \
			--host=${DBHOST} \
			--port=${DBPORT} \
			--batch \
			--skip-column-names -e "show tables" ${DB} \
			| ${SED} 's# #%#g')"
			for TABLE in ${TABLES}
			do
				[[ ! ${TABLES} ]] && continue
				if [[ ! -e "${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}" ]]
				then
					${MKDIR} -p "${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}"
				fi
				if [[ ${PIPECOMP} = yes ]] ; then
					dbdump_table_comp "${DB}" "${TABLE}" "${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}/${TABLE}.sql"
					[[ $? -eq 0 ]] && rotate ${1}
					BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}/${TABLE}.sql${SUFFIX}"
				else
					{
					    dbdump_table "${DB}" "${TABLE}" "${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}/${TABLE}.sql"
					    compression "${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}/${TABLE}.sql"
					} && rotate ${1}
					BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/${1}/${DB}_pertable/${DB}_pertable_${DATE}.${DB}/${TABLE}.sql${SUFFIX}"
				fi
			done
			${ECHO} "----------------------------------------------------------------------"
		else # backup per DB
			[[ ! -e "${BACKUPDIR}/${1}/${DB}" ]] && ${MKDIR} -p "${BACKUPDIR}/${1}/${DB}" # create per db if not exists
			${ECHO} "Monthly Backup of ${DB}..."
		if [[ ${PIPECOMP} = yes ]] ; then
				dbdump_comp "${DB}" "${BACKUPDIR}/${1}/${DB}/${DB}_${DATE}.${DB}.sql"
				[[ $? -eq 0 ]] && rotate ${1}
				BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/${1}/${DB}/${DB}_${DATE}.${DB}.sql${SUFFIX}"
			else
				{
				    dbdump "${DB}" "${BACKUPDIR}/${1}/${DB}/${DB}_${DATE}.${DB}.sql"
				    compression "${BACKUPDIR}/${1}/${DB}/${DB}_${DATE}.${DB}.sql"
				} && rotate ${1}
				BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/${1}/${DB}/${DB}_${DATE}.${DB}.sql${SUFFIX}"
			fi
			${ECHO} "----------------------------------------------------------------------"
		fi
	done
}

1_4_all () {
	${ECHO} "${1} full Backup of \( ${DBNAMES} \)..."
	if [[ $PIPECOMP = yes ]] ; then
		dbdump_comp "$DBNAMES" "$BACKUPDIR/${1}/$DATE.$M.all-databases.sql"
		[[ $? -eq 0 ]] && rotate ${1}
		BACKUPFILES="$BACKUPFILES $BACKUPDIR/${1}/$DATE.$M.all-databases.sql${SUFFIX}"
	else
		{
		    dbdump "${DBNAMES}" "${BACKUPDIR}/${1}/${DATE}.all-databases.sql"
		    compression "${BACKUPDIR}/${1}/${DATE}.all-databases.sql"
		} && rotate ${1}
		BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/${1}/${DATE}.all-databases.sql${SUFFIX}"
	fi
	${ECHO} ----------------------------------------------------------------------
}

prebackup () {
	${ECHO} ======================================================================
	${ECHO} "Prebackup command output."
	${ECHO}
	eval ${PREBACKUP}
	${ECHO}
	${ECHO} ======================================================================
	${ECHO}
}

postbackup () {
	${ECHO} ======================================================================
	${ECHO} "Prebackup command output."
	${ECHO}
	eval ${POSTBACKUP}
	${ECHO}
	${ECHO} ======================================================================
	${ECHO}
}

[[ ${COMMCOMP} = yes ]] && OPT="${OPT} --compress"
[[ ${MAX_ALLOWED_PACKET} ]] && OPT="${OPT} --max_allowed_packet=${MAX_ALLOWED_PACKET}"
[[ ! -e "${BACKUPDIR}" ]] && ${MKDIR} -p "${BACKUPDIR}"
[[ ! -e "${BACKUPDIR}/daily" ]] && ${MKDIR} -p "${BACKUPDIR}/daily"
[[ ! -e "${BACKUPDIR}/weekly" ]] && ${MKDIR} -p "${BACKUPDIR}/weekly"
[[ ! -e "${BACKUPDIR}/monthly" ]] && ${MKDIR} -p "${BACKUPDIR}/monthly"

if [[ "${SEPDIR}" = yes ]] ; then 
	if [[ ${CREATE_DATABASE} = no ]] ; then
		OPT="${OPT} --no-create-db"
	elif [[ ${PERTABLE} = yes ]] ; then
		OPT="${OPT} --no-create-db"
	else
		OPT="${OPT} --databases"
	fi
else
	OPT="${OPT} --databases"
fi

# Hostname for LOG information
if [[ ${DBHOST} = localhost ]] ; then
	HOST=$(${HOSTNAMEC})
	if [[ ${SOCKET} ]] ; then
		OPT="${OPT} --socket=${SOCKET}"
	fi
else
	HOST=${DBHOST}
fi

# If backing up all DBs on the server
if [[ ${DBNAMES} = all ]] ; then
	DBNAMES="$(${MYSQL} \
	--defaults-extra-file=<(${ECHO} $'[client]\npassword='${PASSWORD}) \
	--user="${USERNAME}" \
	--host="${DBHOST}" \
	--port="${DBPORT}" \
	--batch \
	--skip-column-names \
	-e "show databases"\
	| ${SED} 's# #%#g')"

	# If DBs are excluded
	for exclude in ${DBEXCLUDE}
	do
		DBNAMES=$(${ECHO} ${DBNAMES} | ${SED} "s#\<${exclude}\>##g")
	done

	EXCLUDELIST=
	# If excluding tables
	if [[  ${TABLEEXCLUDE} ]] ; then
		for exclude_table in ${TABLEEXCLUDE}
		do
			EXCLUDELIST=" ${EXCLUDELIST} --ignore-table=${exclude_table}"
		done
	fi
	OPT="${OPT} ${EXCLUDELIST}"
fi

[[ ${PREBACKUP} && -f ${PREBACKUP} ]] && prebackup

### backup happenin'
${ECHO} "======================================================================"
${ECHO} "ixsqlbackup VER ${VER}"
${ECHO} 
${ECHO} "Backup of Database Server - ${HOST}"
${ECHO} "======================================================================"
${ECHO} "Backup Start Time $(${DATEC})"
${ECHO} "======================================================================"
case $(((${DDOM} == 1 && ${DNOW} != ${DOWEEKLY})*1+(${DNOW} == ${DOWEEKLY})*2)) in 
	1) # monthly backup
	    case ${SEPDIR} in
		    yes)
			    sepdir monthly
			    ;;
			no)
			    1_4_all monthly
				;;
		esac
		;;
	2) # weekly backup
	    case ${SEPDIR} in
	        yes)
				sepdir weekly
				;;
			no)
			    1_4_all weekly
				;;
        esac
		;;
	*) # daily backup
        case ${SEPDIR} in
		    yes)
				sepdir daily
				;;
			no)
			    1_4_all daily
		        ;;
		esac
		;;
esac
${ECHO} "Backup End Time $(${DATEC})"
${ECHO} "======================================================================"
${ECHO} "Total disk space used for backup storage.."
${ECHO} "Size - Location"
${ECHO} "$(${DU} -hs "${BACKUPDIR}")"
${ECHO}
${ECHO} "======================================================================"

[[ ${POSTBACKUP} && -f ${POSTBACKUP} ]] && postbackup 

#Clean up IO redirection

exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
exec 2>&7 7>&-      # Restore stdout and close file descriptor #7.

if [[ "${MAILCONTENT}" = "files" ]]
then
	if [[ -s ${LOGERR} ]]
	then
		# Include error log if is larger than zero.
		BACKUPFILES="${BACKUPFILES} ${LOGERR}"
		ERRORNOTE="WARNING: Error Reported - "
	fi
	#Get backup size
	ATTSIZE=$(${DU} -c ${BACKUPFILES} | ${GREP} "[[:digit:][:space:]]total$" |${SED} 's#[[:space:]]*total##g' )
	if [[ ${MAXATTSIZE} -ge ${ATTSIZE} ]]
	then
		BACKUPFILES=$(${ECHO} "${BACKUPFILES}" | ${SED} -e "s# # -a #g") #enable multiple attachments
		${MUTT} -s "${ERRORNOTE} MySQL Backup Log and SQL Files for ${HOST} - ${DATE}" ${BACKUPFILES} ${MAILADDR} < ${LOGFILE} #send via mutt
	else
		${CAT} "${LOGFILE}" | ${MAIL_BASE_CMD} -s "WARNING! - MySQL Backup exceeds set maximum attachment size on ${HOST} - ${DATE}" ${MAILADDR}
	fi
elif [[ "${MAILCONTENT}" = "log" ]]
then
	${CAT} "${LOGFILE}" | ${MAIL_BASE_CMD} -s "MySQL Backup Log for ${HOST} - ${DATE}" ${MAILADDR}
	if [[ -s "${LOGERR}" ]]
		then
			${CAT} "${LOGERR}" | ${MAIL_BASE_CMD} -s "ERRORS REPORTED: MySQL Backup error Log for ${HOST} - ${DATE}" ${MAILADDR}
	fi	
elif [[ "${MAILCONTENT}" = "quiet" ]]
then
	if [[ -s ${LOGERR} ]]
		then
			${CAT} "${LOGERR}" | ${MAIL_BASE_CMD} -s "ERRORS REPORTED: MySQL Backup error Log for ${HOST} - ${DATE}" ${MAILADDR}
			${CAT} "${LOGFILE}" | ${MAIL_BASE_CMD} -s "MySQL Backup Log for ${HOST} - ${DATE}" ${MAILADDR}
	fi
else
	if [[ -s ${LOGERR} ]]
		then
			${CAT} "${LOGFILE}"
			${ECHO}
			${ECHO} "###### WARNING ######"
			${ECHO} "Errors encountered whilst backing up... backup job failed!"
			${ECHO} "Error log below.."
			${CAT} "${LOGERR}"
	else
		${CAT} "${LOGFILE}"
	fi	
fi

if [[ -s ${LOGERR} ]]
	then
		STATUS=1
	else
		STATUS=0
fi

exit ${STATUS}