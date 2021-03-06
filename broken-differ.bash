#!/usr/bin/env bash

OPTS=(DBHOST USERNAME PASSWORD DBNAMES DBEXCLUDE TABLEEXLUDE)
tmp=/tmp/check_mysql_dumps
diff_stat=0
stat_diff_daily=0
stat_diff_weekly=0
stat_diff_monthly=0
[[ ! -e ${tmp} ]] && mkdir -p ${tmp}

print_tables () {
	DBNAMES="$(${MYSQL} --defaults-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} --batch --skip-column-names -e "show databases"| ${SED} 's# #%#g')"
	[[ ${DBEXCLUDE} ]] && {
		for db in $(${ECHO} $DBEXCLUDE | ${SED} 's# #\n#g') ; 
		do
			DBNAMES=$(${ECHO} ${DBNAMES} | ${SED} "s#\<${db}\>##g")
		done
		}

	for DB in $(${ECHO} ${DBNAMES} | ${SED} 's# #\n#g')
	do
		TABLES="$(${MYSQL} --defaults-file=<(${ECHO} $'[client]\npassword='${PASSWORD})  --user=${USERNAME} --host=${DBHOST} --port=${DBPORT} --batch --skip-column-names -e "show tables" ${DB} | ${SED} 's# #%#g')"
			[[ ${TABEXCLUDE} ]] && {
				for table in $(${ECHO} $TABLEEXCLUDE | ${SED} 's# #\n#g') ;
				do
					TABLES=$(${ECHO} | ${SED} "s#\<${table}\>##g")
				done
			}
		${ECHO} "${DB}"";"${TABLES} >> ${tmp}/$DBHOST
	done
}

fetch_tables () {
	[[ $(${LS} ${tmp}/*) ]] && ${RM} -f ${tmp}/*
	if [[ ! -s /usr/local/psa/version ]] && [[ ! -s /etc/psa/.psa.shadow ]] ; then
		for LINE in $(${GREP} -Evhr "^#|^$" ${CONFPATH} | ${SED} -e s@" "@"%20%"@g) ; do
        		for ((i=1;i<=${#OPTS[@]};i++)) ; do
			if [[ $i == 1 ]] ; then
		 		eval "${OPTS[i-1]}"="'$(${ECHO} ${LINE} | ${AWK} -F\; '{print $'$i'}' | ${AWK} -F: '{print $1}')'"
				DBPORT=$(${ECHO} ${LINE} | ${AWK} -F\; '{print $'$i'}' | ${AWK} -F: '{print $2}')
				[[ ! ${DBPORT} ]] && DBPORT="3306"
				continue
				fi
			eval "${OPTS[i-1]}"="'$(${ECHO} ${LINE} | ${AWK} -F\; '{print $'$i'}' | ${SED} -e s@"%20%"@" "@g)'"
			done
			print_tables
		done
	elif [[ -s /usr/local/psa/version ]] && [[ -s /etc/psa/.psa.shadow ]] ; then 
		export DBHOST="localhost"
		export DBPORT="3306"
		export USERNAME="admin"
		export PASSWORD=$(${CAT} /etc/psa/.psa.shadow)
		export DBNAMES="all"
		export DBEXCLUDE=""
		export TABLEEXCLUDE=""	
		print_tables
	fi
}

diff_backup () {
    diff -bw \
	    <(ls -1 ${BACKDIR}/${backdirs[i]}/${rota}/${database}_pertable/${folder}/*.* | awk -F "/" '{print $NF}' | sed 's#.sql##g' | sort) \
	    <(${ECHO} ${tabs} | ${SED} 's# #\n#g' | sort) \
	    | ${GREP} "^>"	\
	    | ${SED} ':a;N;$!ba;s#\n# #g; s#> ##g' 
}

check_diffs () {
for ((i=0;i<${#backdirs[@]};i++))
do
	for ((j=1;j<=$(${WC} -l < ${tmp}/${backdirs[i]});j++))
	do
		database=$(${SED} -n ${j}p ${tmp}/${backdirs[i]} | awk -F ";" '{print $1}')
		tabs=$(${SED} -n ${j}p ${tmp}/${backdirs[i]} | awk -F ";" '{print $2}')
		for rota in daily weekly monthly 
		do
		    [[ -d ${BACKDIR}/${backdirs[i]}/${rota}/${database}_pertable/ ]] && {
			    folder=$(ls -1 ${BACKDIR}/${backdirs[i]}/${rota}/${database}_pertable/ | sort | tail -1)
			}
			case $rota in 
				daily)
                    if [[ ! -d ${BACKDIR}/${backdirs[i]}/${rota}/${database}_pertable/ ]] ; then
				 	    diff_daily+=($(${ECHO} "${backdirs[i]}"";"${rota}";"${folder}";""doesnt exist!")) && stat_diff_daily=1
				    else
					    vardiff=$(diff_backup)
					    [[ ${vardiff} ]] && {
						    diff_daily+=($(${ECHO} "${backdirs[i]}"";"${rota}";"${folder}";"${vardiff})) && stat_diff_daily=1
					    }
				    fi
					;;
				weekly)
		            if [[ ! -d ${BACKDIR}/${backdirs[i]}/${rota}/${database}_pertable/ ]] ; then
						diff_daily+=($(${ECHO} "${backdirs[i]}"";"${rota}";"${folder}";""doesnt exist!")) && stat_diff_daily=2
					else
					    vardiff=$(diff_backup)
					    [[ ${vardiff} ]] && {
						    diff_weekly+=($(${ECHO} "${backdirs[i]}"";"${rota}";"${folder}";"${vardiff})) && stat_diff_weekly=2
					    }
					fi
					;;
				monthly)
		            if [[ ! -d ${BACKDIR}/${backdirs[i]}/${rota}/${database}_pertable/ ]] ; then
						diff_daily+=($(${ECHO} "${backdirs[i]}"";"${rota}";"${folder}";""doesnt exist!")) && stat_diff_daily=4
					else
					    vardiff=$(diff_backup)
					    [[ ${vardiff} ]] && {
						    diff_monthly+=($(${ECHO} "${backdirs[i]}"";"${rota}";"${folder}";"${vardiff})) && stat_diff_monthly=4
					    }
					fi
					;;
			esac
		done
	done
done
}


print_diff_daily () {
	for ((i=0;i<${#diff_daily[@]};i++))
	do
		${ECHO} ${diff_daily[i]}
	done
}

print_diff_weekly () {
	for ((i=0;i<${#diff_weekly[@]};i++))
	do
		${ECHO} ${diff_weekly[i]}
	done
}

print_diff_monthly () {
	for ((i=0;i<${#diff_monthly[@]};i++))
	do
		${ECHO} -n ${diff_monthly[i]}
	done
}


diff_stat=$(($stat_diff_daily+$stat_diff_weekly+$stat_diff_monthly))

print_diff () {
	case ${diff_stat} in
	1) print_diff_daily ;;
	2) print_diff_weekly ;;
	3) print_diff_daily && print_diff_weekly ;;
	4) print_diff_monthly ;;
	5) print_diff_daily && print_diff_monthly ;;
	6) print_diff_weekly && print_diff_monthly ;;
	7) print_diff_daily && print_diff_weekly && print_diff_monthly ;;
	0) ${ECHO} -n "" ;;
	esac
}


