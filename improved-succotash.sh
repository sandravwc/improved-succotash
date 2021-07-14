#!/bin/bash
# improved-succotash.sh
# VER 1
#
# BASED ON:
#
# MySQL Backup Script
# VER. 2.6.8 - http://sourceforge.net/projects/automysqlbackup/
# Copyright (c) 2002-2003 wipe_out@lycos.co.uk
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#=====================================================================
#=====================================================================
# Set the following variables to your system needs
# (Detailed instructions below variables)
#=====================================================================
#set -x
CONFIGFILE="/home/backup/automysqlbackup.conf"

if [ -r ${CONFIGFILE} ]; then
	# Read the configfile if it's existing and readable
	source ${CONFIGFILE}
else
	# do inline-config otherwise
	# To create a configfile just copy the code between "### START CFG ###" and "### END CFG ###"
	# to /etc/automysqlbackup/automysqlbackup.conf. After that you're able to upgrade this script
	# (copy a new version to its location) without the need for editing it.
	### START CFG ###
	# Username to access the MySQL server e.g. dbuser
	USERNAME=`echo ${USERNAME:=dbuser}`
	
	# Password to access the MySQL server e.g. password
	PASSWORD=`echo ${PASSWORD:=password}`
	# Host name (or IP address) of MySQL server e.g localhost
	DBHOST=`echo ${DBHOST:=localhost}`
	# Port where MYSQL Server is listening
	DBPORT=`echo ${DBPORT:=3306}`
	
	# List of DBNAMES for Daily/Weekly Backup e.g. "DB1 DB2 DB3"
	DBNAMES=`echo ${DBNAMES:="DB1 DB2 DB3"}`
	
	# Backup directory location e.g /backups
	BACKUPDIR=`echo ${BACKUPDIR:="/backup/mysql/${DBHOST}"}`

	# Mail setup
	# What would you like to be mailed to you?
	# - log   : send only log file
	# - files : send log file and sql files as attachments (see docs)
	# - stdout : will simply output the log to the screen if run manually.
	# - quiet : Only send logs if an error occurs to the MAILADDR.
	MAILCONTENT="quiet"
	
	# Set the maximum allowed email size in k. (4000 = approx 5MB email [see docs])
	MAXATTSIZE="4000"
	
	# Email Address to send mail to? (user@domain.com)
	MAILADDR=`echo ${MAILADDR:="maintenance@example.com"}`
	
	# Email Address to send mail from? (root@host.tld)
	FROMADDR="automysqlbackup@`hostname -f`"

	# List of DBBNAMES for Monthly Backups.
	MDBNAMES="${DBNAMES}"
	
	# List of DBNAMES to EXLUCDE if DBNAMES are set to all (must be in " quotes)
	DBEXCLUDE=`echo ${DBEXCLUDE:=""}`
	
	# List of tables to exclude. Space-separated, with db name, e.g. "db1.table1 d2.table2"
	TABLEEXCLUDE=`echo ${TABLEEXCLUDE:=""}`

	# Include CREATE DATABASE in backup?
	CREATE_DATABASE=yes
	
	# Separate backup directory and file for each DB? (yes or no)
	SEPDIR=yes
	
	# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
	DOWEEKLY=6
	
	# Choose Compression type. (gzip or bzip2)
	COMP=`echo ${COMP:=gzip}`

	# Use pipe compress
	PIPECOMP=no

	# Compress communications between backup server and MySQL server?
	COMMCOMP=no
	
	# Additionally keep a copy of the most recent backup in a seperate directory.
	LATEST=no
	
	#  The maximum size of the buffer for client/server communication. e.g. 16MB (maximum is 1GB)
	MAX_ALLOWED_PACKET=
	
	# doesnt show messages about rotating backups...
	QUIETROTA=`echo ${QUIETROTA:=no}`

	#  For connections to localhost. Sometimes the Unix socket file must be specified.
	SOCKET=

	# Backup databases per table work if SEPDIR set to `yes'                                                            
	PERTABLE=yes                                                                                                        
 
	# Command to run before backups (uncomment to use)
	#PREBACKUP="/etc/mysql-backup-pre"
	
	# Command run after backups (uncomment to use)
	#POSTBACKUP="/etc/mysql-backup-post"
	### END CFG ###
fi

#=====================================================================
# Change Log
#=====================================================================
# improved-succotash.sh V1 (2021-07-09)
#     - fix mysql and mysqldump warn message behaviour by substituting defaults file (MaRz)
#     - fix bug where listing databases and tables with all option didn't take port as argument (MaRz)
#     - add option to quiet compression option if no comperession is set (MaRz)
#     - add option to quiet rotation messages (MaRz)
#
# feel free to fuck around with the script down here
#
#=====================================================================
#=====================================================================
#=====================================================================
#
# Full pathname to binaries to avoid problems with aliases and builtins etc.
#
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/mysql/bin

WHICH="`which which`"
AWK="`${WHICH} gawk`"
LOGGER="`${WHICH} logger`"
ECHO="`${WHICH} echo`"
CAT="`${WHICH} cat`"
BASENAME="`${WHICH} basename`"
DATEC="`${WHICH} date`"
DU="`${WHICH} du`"
EXPR="`${WHICH} expr`"
FIND="`${WHICH} find`"
RM="`${WHICH} rm`"
MYSQL="`${WHICH} mysql`"
MYSQLDUMP="`${WHICH} mysqldump`"
GZIP="`${WHICH} gzip`"
BZIP2="`${WHICH} bzip2`"
CP="`${WHICH} cp`"
HOSTNAMEC="`${WHICH} hostname`"
SED="`${WHICH} sed`"
GREP="`${WHICH} grep`"
NAIL="`${WHICH} nail 2>/dev/null`"
MMAIL="`${WHICH} mail 2>/dev/null`"
SMBIN="`${WHICH} sendmail 2>/dev/null`"
READLINK="`${WHICH} readlink 2>/dev/null`"

function is_sendmail_qmail {
	while [ -L ${SMBIN} ] ; do
		SMBIN=`${READLINK} -e ${SMBIN}`
	done
	if [ -z "`echo ${SMBIN} | ${GREP} -i qmail`" ] ; then
		echo 0
	else
		echo 1
	fi
}

function get_events_support {
	if [ -z "`${MYSQLDUMP} --events 2>&1 | ${GREP} \"unknown option\"`" ] ; then
		echo 1
	else
		echo 0
	fi
}

if [ -z "${NAIL}" ] ; then
	if [ -n "${MMAIL}" ] ; then
		if [ -n "`${MMAIL} -r 2>&1 | grep \"invalid option -- r\"`" ]; then
			# mail doesn't support -r
			echo "No working 'mail' command found"
			echo "Install nail which support -r option!"
			exit 1
		else
			MAILCMD=${MMAIL}
		fi
	fi
else
		MAILCMD=${NAIL}
fi

# sendmail replacement of qmail does not support -r option
if [ "`is_sendmail_qmail`" == "1" ] ; then
	MAIL_BASE_CMD="${MAILCMD}"
else
	MAIL_BASE_CMD="${MAILCMD} -r ${FROMADDR}"
fi

function get_debian_pw() {
	if [ -r /etc/mysql/debian.cnf ]; then
		eval $(${AWK} '
			! user && /^[[:space:]]*user[[:space:]]*=[[:space:]]*/ {
				print "USERNAME=" gensub(/.+[[:space:]]+([^[:space:]]+)[[:space:]]*$/, "\\1", "1"); user++
			}
			! pass && /^[[:space:]]*password[[:space:]]*=[[:space:]]*/ {
				print "PASSWORD=" gensub(/.+[[:space:]]+([^[:space:]]+)[[:space:]]*$/, "\\1", "1"); pass++
			}' /etc/mysql/debian.cnf
		)
	else
		${LOGGER} "${PROGNAME}: File \"/etc/mysql/debian.cnf\" not found."
		exit 1
	fi
}

[ "x${USERNAME}" = "xdebian" -a "x${PASSWORD}" = "x" ] && get_debian_pw 

while [ $# -gt 0 ]; do
	case $1 in
		-c)
			if [ -r "$2" ]; then
				source "$2"
				shift 2
			else
				${ECHO} "Ureadable config file \"$2\""
				exit 1
			fi
			;;
		*)
			${ECHO} "Unknown Option \"$1\""
			exit 2
			;;
	esac
done

export LC_ALL=C
PROGNAME=`${BASENAME} $0`
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin 
DATE=`${DATEC} +%Y-%m-%d_%Hh%Mm`				# Datestamp e.g 2002-09-21
DOW=`${DATEC} +%A`							# Day of the week e.g. Monday
DNOW=`${DATEC} +%u`						# Day number of the week 1 to 7 where 1 represents Monday
DOM=`${DATEC} +%d`							# Date of the Month e.g. 27
M=`${DATEC} +%B`							# Month e.g January
W=`${DATEC} +%V`							# Week Number e.g 37
VER=2.6.8-IX									# Version Number
LOGFILE=${BACKUPDIR}/${DBHOST}-`${DATEC} +%N`.log		# Logfile Name
LOGERR=${BACKUPDIR}/ERRORS_${DBHOST}-`${DATEC} +%N`.log		# Logfile Name
BACKUPFILES=""
if [ "`get_events_support`" == "1" ] ; then
	OPT="--events --ignore-table=mysql.events --quote-names --opt --single-transaction --routines"	# OPT string for use with mysqldump ( see man mysqldump )
else
	OPT="--quote-names --opt --single-transaction --routines"			# OPT string for use with mysqldump ( see man mysqldump )
fi
# IO redirection for logging.
touch ${LOGFILE}
exec 6>&1           # Link file descriptor #6 with stdout.
                    # Saves stdout.
exec > ${LOGFILE}     # stdout replaced with file ${LOGFILE}.
touch ${LOGERR}
exec 7>&2           # Link file descriptor #7 with stderr.
                    # Saves stderr.
exec 2> ${LOGERR}     # stderr replaced with file ${LOGERR}.

# Add --compress mysqldump option to ${OPT}
if [ "${COMMCOMP}" = "yes" ];
	then
		OPT="${OPT} --compress"
	fi

# Add --max_allowed_packet=... mysqldump option to ${OPT}
if [ "${MAX_ALLOWED_PACKET}" ];
	then
		OPT="${OPT} --max_allowed_packet=${MAX_ALLOWED_PACKET}"
	fi

# Create required directories
if [ ! -e "${BACKUPDIR}" ]		# Check Backup Directory exists.
	then
	mkdir -p "${BACKUPDIR}"
fi

if [ ! -e "${BACKUPDIR}/daily" ]		# Check Daily Directory exists.
	then
	mkdir -p "${BACKUPDIR}/daily"
fi

if [ ! -e "${BACKUPDIR}/weekly" ]		# Check Weekly Directory exists.
	then
	mkdir -p "${BACKUPDIR}/weekly"
fi

if [ ! -e "${BACKUPDIR}/monthly" ]	# Check Monthly Directory exists.
	then
	mkdir -p "${BACKUPDIR}/monthly"
fi

if [ "${LATEST}" = "yes" ]
then
	if [ ! -e "${BACKUPDIR}/latest" ]	# Check Latest Directory exists.
	then
		mkdir -p "${BACKUPDIR}/latest"
	fi
eval ${RM} -fv "${BACKUPDIR}/latest/*"
fi



# Functions

# Database dump function
dbdump () {
${MYSQLDUMP} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} ${OPT} ${1} > ${2}
return $?
}

dbdump_comp () {
if [ "$COMP" = "gzip" ]; then
	${ECHO} Backup Information for "${1}.gz"
	SUFFIX=".gz"
	${MYSQLDUMP} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} ${OPT} ${1} | ${GZIP} > ${2}${SUFFIX}
	${GZIP} -l "$1.gz"
elif [ "$COMP" = "bzip2" ]; then
	${ECHO} Compression information for "${1}.bz2"
	SUFFIX=".bz2"
	${MYSQLDUMP} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} ${OPT} ${1} | ${BZIP2} -v 2>&1 > ${2}${SUFFIX}
else
	[ "$COMP" = "no" ] || ${ECHO} "No compression option set, check advanced settings"
fi
return $?
}

dbdump_table () {
if [ -n "`echo ${TABLEEXCLUDE} | grep \"${1}.${2}\"`" ] ; then
	OPT=`echo ${OPT} | ${SED} -e 's@ --opt @ --skip-opt @'`
fi
 ${MYSQLDUMP} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} ${OPT} ${1} ${2} > ${3}
return $?
}

dbdump_table_comp () {
if [ -n "`echo ${TABLEEXCLUDE} | grep \"${1}.${2}\"`" ] ; then
        OPT=`echo ${OPT} | ${SED} -e 's@ --opt @ --skip-opt @'`
fi
if [ "${COMP}" = "gzip" ]; then
	echo
	echo Backup     Information     for "$3.gz"
	SUFFIX=".gz"
	${MYSQLDUMP} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} ${OPT} ${1} ${2} | ${GZIP} > ${3}${SUFFIX}
	${GZIP} -l "${3}.gz"
elif [ "${COMP}" = "bzip2" ]; then
	echo Compression information for "${3}.bz2"
	SUFFIX=".bz2"
	${MYSQLDUMP} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} ${OPT} ${1} ${2} | ${BZIP2} -v 2>&1 > ${3}${SUFFIX}
else
	[ "$COMP" = "no" ] echo "No compression option set, check advanced settings"
fi
return $?
}
# Compression function plus latest copy
SUFFIX=""
compression () {
if [ "${COMP}" = "gzip" ]; then
	${GZIP} -f "${1}"
	${ECHO}
	${ECHO} Backup Information for "${1}.gz"
	${GZIP} -l "${1}.gz"
	SUFFIX=".gz"
elif [ "${COMP}" = "bzip2" ]; then
	${ECHO} Compression information for "${1}.bz2"
	${BZIP2} -f -v ${1} 2>&1
	SUFFIX=".bz2"
else
	[ "$COMP" = "no" ] || ${ECHO} "No compression option set, check advanced settings"
fi
if [ "${LATEST}" = "yes" ]; then
	${CP} ${1}${SUFFIX} "${BACKUPDIR}/latest/"
fi	
return 0
}

# Run command before we begin
if [ "${PREBACKUP}" ]
	then
	${ECHO} ======================================================================
	${ECHO} "Prebackup command output."
	${ECHO}
	eval ${PREBACKUP}
	${ECHO}
	${ECHO} ======================================================================
	${ECHO}
fi


if [ "${SEPDIR}" = "yes" ]; then # Check if CREATE DATABSE should be included in Dump
	if [ "${CREATE_DATABASE}" = "no" ]; then
		OPT="${OPT} --no-create-db"
	elif [ "${PERTABLE}" = "yes" ]; then
		OPT="${OPT} --no-create-db"
	else
		OPT="${OPT} --databases"
	fi
else
	OPT="${OPT} --databases"
fi

# Hostname for LOG information
if [ "${DBHOST}" = "localhost" ]; then
	HOST=`${HOSTNAMEC}`
	if [ "${SOCKET}" ]; then
		OPT="${OPT} --socket=${SOCKET}"
	fi
else
	HOST=${DBHOST}
fi

# If backing up all DBs on the server
if [ "${DBNAMES}" = "all" ]; then
        DBNAMES="`${MYSQL} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} --batch --skip-column-names -e "show databases"| ${SED} 's/ /%/g'`"

	# If DBs are excluded
	for exclude in ${DBEXCLUDE}
	do
		DBNAMES=`${ECHO} ${DBNAMES} | ${SED} "s/\b${exclude}\b//g"`
	done

        MDBNAMES=${DBNAMES}

	EXCLUDELIST=
	# If excluding tables
	if [ -n "${TABLEEXCLUDE}" ]; then
		for exclude_table in ${TABLEEXCLUDE}
		do
			EXCLUDELIST=" ${EXCLUDELIST} --ignore-table=${exclude_table}"
		done
	fi
	OPT="${OPT} ${EXCLUDELIST}"
fi
	
${ECHO} ======================================================================
${ECHO} AutoMySQLBackup VER ${VER}
${ECHO} OBLIGATORY GITLAB LINK
${ECHO} 
${ECHO} Backup of Database Server - ${HOST}
${ECHO} ======================================================================

# Test is seperate DB backups are required
if [ "${SEPDIR}" = "yes" ]; then
${ECHO} Backup Start Time `${DATEC}`
${ECHO} ======================================================================
	# Monthly Full Backup of all Databases
	if [ ${DOM} = "01" ]; then
		for MDB in ${MDBNAMES}
		do
 
			 # Prepare ${DB} for using
		        MDB="`${ECHO} ${MDB} | ${SED} 's/%/ /g'`"

			if [ "${PERTABLE}" = "yes"  ];  # Check backup per table
			then  # Start Monthly DB backup per table
				echo Monthly Backup of ${MDB} per table...
				TABLES="`${MYSQL} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} --batch --skip-column-names -e "show tables" ${MDB} | ${SED} 's/ /%/g'`"
				for TABLE in $TABLES
				do
					if [ ! -e "${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}" ] # Check Monthly DB per table Directory exists.
					then
						mkdir -p "${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}"
					fi
					if [ "${PIPECOMP}" = "yes" ]; then
						dbdump_table_comp "${MDB}" "${TABLE}" "${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}/${TABLE}.sql"
						BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}/${TABLE}.sql${SUFFIX}"
					else
						dbdump_table "${MDB}" "${TABLE}" "${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}/${TABLE}.sql"
						compression     "${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}/${TABLE}.sql"
						BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/monthly/${MDB}_pertable/${MDB}_pertable_${DATE}.${M}.${MDB}/${TABLE}.sql${SUFFIX}"
					fi
				done
				echo ----------------------------------------------------------------------
			else    # Start Monthly DB full
				if [ ! -e "${BACKUPDIR}/monthly/${MDB}" ]           # Check Monthly DB Directory exists.
				then
					mkdir -p "${BACKUPDIR}/monthly/${MDB}"
				fi

				echo Monthly Backup of ${MDB}...
				if [ "${PIPECOMP}" = "yes" ]; then
					dbdump_comp "${MDB}" "${BACKUPDIR}/monthly/${MDB}/${MDB}_${DATE}.${M}.${MDB}.sql"
					BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/monthly/${MDB}/${MDB}_${DATE}.${M}.${MDB}.sql${SUFFIX}"
				else
					dbdump "${MDB}" "${BACKUPDIR}/monthly/${MDB}/${MDB}_${DATE}.${M}.${MDB}.sql"
					compression "${BACKUPDIR}/monthly/${MDB}/${MDB}_${DATE}.${M}.${MDB}.sql"
					BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/monthly/${MDB}/${MDB}_${DATE}.${M}.${MDB}.sql${SUFFIX}"
				fi
				echo  ----------------------------------------------------------------------
			fi
		done
	fi

	for DB in ${DBNAMES}
	do
	# Prepare ${DB} for using
	DB="`${ECHO} ${DB} | ${SED} 's/%/ /g'`"
	
	# Create Seperate directory for each DB
	if [ "${PERTABLE}" = "yes"  ];
	then
		if [ ! -e "${BACKUPDIR}/daily/${DB}_pertable" ]           # Check Daily DB per table Directory exists.
		then
			mkdir -p "${BACKUPDIR}/daily/${DB}_pertable"
		fi

		if [ ! -e "${BACKUPDIR}/weekly/${DB}_pertable" ]          # Check Weekly DB per table Directory exists.
		then
			mkdir -p "${BACKUPDIR}/weekly/${DB}_pertable"
		fi
	else
		if [ ! -e "${BACKUPDIR}/daily/${DB}" ]              # Check Daily DB Directory exists.
		then
			mkdir -p "${BACKUPDIR}/daily/${DB}"
		fi

		if [ ! -e "${BACKUPDIR}/weekly/${DB}" ]             # Check Weekly DB Directory exists.
		then
			mkdir -p "${BACKUPDIR}/weekly/${DB}"
		fi
	fi
	
	# Weekly Backup
	if [ ${DNOW} = ${DOWEEKLY} ]; then
		${ECHO} Weekly Backup of Database \( ${DB} \)
		${ECHO}
		if [ "$PERTABLE" = "yes"  ];
		then
			if [ ! -e "$BACKUPDIR/weekly/${DB}_pertable/${DB}_pertable.week.$W.$DATE" ]             # Check Weekly DB per table Directory exists.
			then
				mkdir -p "$BACKUPDIR/weekly/${DB}_pertable/${DB}_pertable.week.$W.$DATE"
			fi
			TABLES="`${MYSQL} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} --batch --skip-column-names -e "show tables" ${DB} | ${SED} 's/ /%/g'`"
			for TABLE in ${TABLES}
			do
				if [ "$PIPECOMP" = "yes" ]; then
					dbdump_table_comp "${DB}" "${TABLE}" "${BACKUPDIR}/weekly/${DB}_pertable/${DB}_pertable.week.${W}.${DATE}/${TABLE}.sql"
					[ $? -eq 0 ] && {
						[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating 5 weeks Backups ${DB}.${TABLE}...
						${FIND} "${BACKUPDIR}/weekly/${DB}_pertable" -mtime +35 -type f -exec ${RM} -v {} \;
					}
					BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/weekly/${DB}_pertable/${DB}_pertable.week.${W}.${DATE}/${TABLE}.sql${SUFFIX}"
				else
					dbdump_table "${DB}" "${TABLE}" "${BACKUPDIR}/weekly/${DB}_pertable/${DB}_pertable.week.${W}.${DATE}/${TABLE}.sql"
					[ $? -eq 0 ] && {
						[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating 5 weeks Backups ${DB}.${TABLE}...
						${FIND} "${BACKUPDIR}/weekly/${DB}_pertable" -mtime +35 -type f -exec ${RM} -v {} \;
					}
					compression     "${BACKUPDIR}/weekly/${DB}_pertable/${DB}_pertable.week.${W}.${DATE}/${TABLE}.sql"
					BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/weekly/${DB}_pertable/${DB}_pertable.week.${W}.${DATE}/${TABLE}.sql${SUFFIX}"
				fi
			done
		else
			if [ "$PIPECOMP" = "yes" ]; then
				dbdump_comp "$DB" "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql"
				[ $? -eq 0 ] && {
					[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating 5 weeks Backups...
					${FIND} "${BACKUPDIR}/weekly/${DB}" -mtime +35 -type f -exec ${RM} -v {} \;
				}
				BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/weekly/${DB}/${DB}_week.${W}.${DATE}.sql${SUFFIX}"
			else
				dbdump "${DB}" "${BACKUPDIR}/weekly/${DB}/${DB}_week.${W}.${DATE}.sql"
				[ $? -eq 0 ] && {
					[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating 5 weeks Backups...
					${FIND} "${BACKUPDIR}/weekly/${DB}" -mtime +35 -type f -exec ${RM} -v {} \; 
				}
				compression "${BACKUPDIR}/weekly/${DB}/${DB}_week.${W}.${DATE}.sql"
				BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/weekly/${DB}/${DB}_week.${W}.${DATE}.sql${SUFFIX}"
			fi
		fi
		${ECHO} ----------------------------------------------------------------------
	
	# Daily Backup
	else
		${ECHO} Daily Backup of Database \( ${DB} \)
		${ECHO}
		if [ "$PERTABLE" = "yes"  ];
		then
			if [ ! -e "$BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW" ]         # Check Daily DB per table Directory exists.
			then
				mkdir -p "$BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW"
			fi
			TABLES="`${MYSQL} --defaults-extra-file=<(echo $'[client]\npassword='${PASSWORD}) --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} --batch --skip-column-names -e "show tables" ${DB} | ${SED} 's/ /%/g'`"
			for TABLE in ${TABLES}
			do
				if [ "$PIPECOMP" = "yes" ]; then
					dbdump_table_comp "$DB" "$TABLE" "$BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW/$TABLE.sql"
					[ $? -eq 0 ] && {
						[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating last weeks Backup ${DB}.${TABLE}...
						${FIND} "${BACKUPDIR}/daily/${DB}_pertable" -mtime +5 -type f -exec ${RM} -v {} \;
					}
					BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW/$TABLE.sql$SUFFIX"
				else
					dbdump_table "$DB" "$TABLE" "$BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW/$TABLE.sql"
					[ $? -eq 0 ] && {
						[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating last weeks Backup ${DB}.${TABLE}...
						${FIND} "${BACKUPDIR}/daily/${DB}_pertable" -mtime +5 -type f -exec ${RM} -v {} \;
					}
					compression     "$BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW/$TABLE.sql"
					BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/${DB}_pertable/${DB}_pertable_$DATE.$DOW/$TABLE.sql$SUFFIX"
				fi
			done
		else
			if [ "$PIPECOMP" = "yes" ]; then
				dbdump_comp "$DB" "$BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql"
				[ $? -eq 0 ] && {
					[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating last weeks Backup ${DB}.${TABLE}...
					${FIND} "${BACKUPDIR}/daily/${DB}" -mtime +6 -type f -exec ${RM} -v {} \;
				}
				BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql$SUFFIX"
			else
				dbdump "${DB}" "${BACKUPDIR}/daily/${DB}/${DB}_${DATE}.${DOW}.sql"
				[ $? -eq 0 ] && {
					[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating last weeks Backup ${DB}.${TABLE}...
					${FIND} "${BACKUPDIR}/daily/${DB}" -mtime +6 -type f -exec ${RM} -v {} \; 
				}
				compression "${BACKUPDIR}/daily/${DB}/${DB}_${DATE}.${DOW}.sql"
				BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/daily/${DB}/${DB}_${DATE}.${DOW}.sql${SUFFIX}"
			fi
		fi
		${ECHO} ----------------------------------------------------------------------
	fi
	done
${ECHO} Backup End `${DATEC}`
${ECHO} ======================================================================


else # One backup file for all DBs
${ECHO} Backup Start `${DATEC}`
${ECHO} ======================================================================
	# Monthly Full Backup of all Databases
	if [ ${DOM} = "01" ]; then
		${ECHO} Monthly full Backup of \( ${MDBNAMES} \)...
		if [ "$PIPECOMP" = "yes" ]; then
			dbdump_comp "$MDBNAMES" "$BACKUPDIR/monthly/$DATE.$M.all-databases.sql"
			[ $? -eq 0 ] && {
				[ "$QUIETROTA" = "yes" ] || ${ECHO} "Rotating 5 month backups ${DB}..."
				${FIND} "${BACKUPDIR}/monthly" -mtime +150 -type f -exec ${RM} -v {} \;
			}
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/monthly/$DATE.$M.all-databases.sql$SUFFIX"
		else
			dbdump "${MDBNAMES}" "${BACKUPDIR}/monthly/${DATE}.${M}.all-databases.sql"
			[ $? -eq 0 ] && {
				[ "$QUIETROTA" = "yes" ] || ${ECHO} "Rotating 5 month backups ${DB}..."
				${FIND} "${BACKUPDIR}/monthly" -mtime +150 -type f -exec ${RM} -v {} \; 
			}
			compression "${BACKUPDIR}/monthly/${DATE}.${M}.all-databases.sql"
			BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/monthly/${DATE}.${M}.all-databases.sql${SUFFIX}"
		fi
		${ECHO} ----------------------------------------------------------------------
	fi

	# Weekly Backup
	if [ ${DNOW} = ${DOWEEKLY} ]; then
		${ECHO} Weekly Backup of Databases \( ${DBNAMES} \)
		${ECHO}
		${ECHO}
		if [ "$PIPECOMP" = "yes" ]; then
			dbdump_comp     "$DBNAMES" "$BACKUPDIR/weekly/week.$W.$DATE.sql"
			[ $? -eq 0 ] && {
				[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating 5 weeks Backups ${DB}...
				${FIND} "${BACKUPDIR}/weekly/" -mtime +35 -type f -exec ${RM} -v {} \;
			}
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/weekly/week.$W.$DATE.sql$SUFFIX"
		else
			dbdump "${DBNAMES}" "${BACKUPDIR}/weekly/week.${W}.${DATE}.sql"
			[ $? -eq 0 ] && {
				[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating 5 weeks Backups ${DB}...
				${FIND} "${BACKUPDIR}/weekly/" -mtime +35 -type f -exec ${RM} -v {} \; 
			}
			compression "${BACKUPDIR}/weekly/week.${W}.${DATE}.sql"
			BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/weekly/week.${W}.${DATE}.sql${SUFFIX}"
		fi
		${ECHO} ----------------------------------------------------------------------
		
	# Daily Backup
	else
		${ECHO} Daily Backup of Databases \( ${DBNAMES} \)
		${ECHO}
		${ECHO}
		if [ "$PIPECOMP" = "yes" ]; then
			dbdump_comp "$DBNAMES" "$BACKUPDIR/daily/$DATE.$DOW.sql"
			[ $? -eq 0 ] && {
				[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating last weeks Backup ${DB}...
				${FIND} "${BACKUPDIR}/daily" -mtime +6 -type f -exec ${RM} -v {} \;
			}
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/$DATE.$DOW.sql$SUFFIX"
		else
			dbdump "${DBNAMES}" "${BACKUPDIR}/daily/${DATE}.${DOW}.sql"
			[ $? -eq 0 ] && {
				[ "$QUIETROTA" = "yes" ] || ${ECHO} Rotating last weeks Backup ${DB}...
				${FIND} "${BACKUPDIR}/daily" -mtime +6 -type f -exec ${RM} -v {} \; 
			}
			compression "${BACKUPDIR}/daily/${DATE}.${DOW}.sql"
			BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/daily/${DATE}.${DOW}.sql${SUFFIX}"
		fi
		${ECHO} ----------------------------------------------------------------------
	fi
${ECHO} Backup End Time `${DATEC}`
${ECHO} ======================================================================
fi
${ECHO} Total disk space used for backup storage..
${ECHO} Size - Location
${ECHO} `${DU} -hs "${BACKUPDIR}"`
${ECHO}
${ECHO} ======================================================================
${ECHO} whatever buddy
${ECHO} ======================================================================

# Run command when we're done
if [ "${POSTBACKUP}" ]
	then
	${ECHO} ======================================================================
	${ECHO} "Postbackup command output."
	${ECHO}
	eval ${POSTBACKUP}
	${ECHO}
	${ECHO} ======================================================================
fi

#Clean up IO redirection
exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
exec 2>&7 7>&-      # Restore stdout and close file descriptor #7.

if [ "${MAILCONTENT}" = "files" ]
then
	if [ -s "${LOGERR}" ]
	then
		# Include error log if is larger than zero.
		BACKUPFILES="${BACKUPFILES} ${LOGERR}"
		ERRORNOTE="WARNING: Error Reported - "
	fi
	#Get backup size
	ATTSIZE=`${DU} -c ${BACKUPFILES} | ${GREP} "[[:digit:][:space:]]total$" |${SED} s/\s*total//`
	if [ ${MAXATTSIZE} -ge ${ATTSIZE} ]
	then
		BACKUPFILES=`${ECHO} "${BACKUPFILES}" | ${SED} -e "s# # -a #g"`	#enable multiple attachments
		mutt -s "${ERRORNOTE} MySQL Backup Log and SQL Files for ${HOST} - ${DATE}" ${BACKUPFILES} ${MAILADDR} < ${LOGFILE}		#send via mutt
	else
		${CAT} "${LOGFILE}" | ${MAIL_BASE_CMD} -s "WARNING! - MySQL Backup exceeds set maximum attachment size on ${HOST} - ${DATE}" ${MAILADDR}
	fi
elif [ "${MAILCONTENT}" = "log" ]
then
	${CAT} "${LOGFILE}" | ${MAIL_BASE_CMD} -s "MySQL Backup Log for ${HOST} - ${DATE}" ${MAILADDR}
	if [ -s "${LOGERR}" ]
		then
			${CAT} "${LOGERR}" | ${MAIL_BASE_CMD} -s "ERRORS REPORTED: MySQL Backup error Log for ${HOST} - ${DATE}" ${MAILADDR}
	fi	
elif [ "${MAILCONTENT}" = "quiet" ]
then
	if [ -s "${LOGERR}" ]
		then
			${CAT} "${LOGERR}" | ${MAIL_BASE_CMD} -s "ERRORS REPORTED: MySQL Backup error Log for ${HOST} - ${DATE}" ${MAILADDR}
			${CAT} "${LOGFILE}" | ${MAIL_BASE_CMD} -s "MySQL Backup Log for ${HOST} - ${DATE}" ${MAILADDR}
	fi
else
	if [ -s "${LOGERR}" ]
		then
			${CAT} "${LOGFILE}"
			${ECHO}
			${ECHO} "###### WARNING ######"
			${ECHO} "Errors reported during AutoMySQLBackup execution.. Backup failed"
			${ECHO} "Error log below.."
			${CAT} "${LOGERR}"
	else
		${CAT} "${LOGFILE}"
	fi	
fi

if [ -s "${LOGERR}" ]
	then
		STATUS=1
	else
		STATUS=0
fi
# Clean up Logfile
eval ${RM} -f "${LOGFILE}"
eval ${RM} -f "${LOGERR}"
exit ${STATUS}

# todo: make use of getopts
# todo: make rotation variable
# todo: get rid of log handling in this script
# todo: add support for backing up multiple servers
#
