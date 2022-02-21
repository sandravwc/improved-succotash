#!/usr/bin/env bash
# check_mysql_dumps
# do da check of how old my dumps are
# VER 2.0
####################################################################################
####################################################################################
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/mysql/bin:/root/bin  ##
VER="2.0"                                                                         ##
ENV=$(which env)                                                                  ##
WHICH=$(${ENV} which which)                                                       ##
GREP=$(${WHICH} grep)                                                             ##
SED=$(${WHICH} sed)                                                               ##
AWK=$(${WHICH} awk)                                                               ##
ECHO=$(${WHICH} echo)                                                             ##
SH=$(${WHICH} sh)                                                                 ##
TOUCH=$(${WHICH} touch)                                                           ##
RM=$(${WHICH} rm)                                                                 ##
LS=$(${WHICH} ls)                                                                 ##
CAT=$(${WHICH} cat)                                                               ##
MYSQL=$(${WHICH} mysql)                                                           ##
WC=$(${WHICH} wc)                                                                 ##
DATEC=$(${WHICH} date)                                                            ##
DATE=$(${DATEC} +%Y-%m-%d)                                                        ##
DATEM=$(${DATEC} +%H%M)                                                           ##
DOM=$(${DATEC} +%d)                                                               ##
DOW=$(${DATEC} +%u)                                                               ##
DDOM=$((10#${DOM}))                                                               ##
DDATEM=$((10#${DATEM}))                                                           ##
fopts=0                                                                           ##
####################################################################################
####################################################################################
#set -x
OPTS=(DBHOST USERNAME PASSWORD DBNAMES DBEXCLUDE TABLEEXLUDE)

help () {
${ECHO} -en "Usage:
\t $0 -c conf
\t Path to multimysqlbackup conf file or folder \n
\t $0 -b backdir 
\t Path to backup directory \n
\t $0 -r rota
\t Rotations to check against (daily weekly monthly)
\t Example: $0 -c /etc/multimysqlbackup.d -b /backup/mysql
\t Example: $0 -c /etc/multimysqlbackup.conf -b /backup/mysql -r daily monthly \n"
	exit 0
}

while getopts c:b:r:h locs
do
	case $locs in
		c)	
			CONFPATH=$OPTARG;fopts=$fopts+1 
			;;
		b)	
			BACKDIR=$OPTARG;fopts=$fopts+1 
			;;
		r)
      IFS=','
		  ROTA+=($OPTARG);fopts=$fopts+1
			unset IFS
			;;
		h)	
			HELP=1 
			;;
		?)	
			${ECHO} "excuse me?" 
			;;
	esac
done

[[ ! ${CONFPATH} ]] && CONFPATH="/usr/local/etc/multimysqlbackup.d"
[[ ! ${BACKDIR} ]] && BACKDIR="/backup/mysql"
IFS=$'\n'
day=$((60**2*24))
week=$(($day*7))
month=$(($day*30))
warn_daily=$day 
[[ ${DDOM} == 1 && $(${DATEC} --date='-1 day' +%u) == 1 ]] && warn_daily=$(($day*2))
[[ ${DOW} == 1 && $((10#$(${DATEC} --date='-1 day' +%d))) == 1 ]] && warn_daily=$(($day*2))
crit_daily=$(($warn_daily + $day))
warn_weekly=$(($week + $day))
crit_weekly=$(($warn_weekly + $crit_daily))
warn_monthly=$(($month + $day))
crit_monthly=$(($warn_monthly + $crit_daily))
now=$(${DATEC} +'%s')
stat=0
stat_warn=0
stat_crit=0
if [[ ! -s /usr/local/psa/version ]] && [[ ! -s /etc/psa/.psa.shadow ]] ; then
	backdirs+=($(${AWK} -F ";" '{print $1}' <(${GREP} -Evhr "^#|^$" ${CONFPATH}) | ${AWK} -F ":" '{print $1}'))
elif [[ -s /usr/local/psa/version ]] && [[ -s /etc/psa/.psa.shadow ]] ; then
    backdirs+=($(${ECHO} localhost))
fi
[[ ${HELP} == 1 ]] && help


checko () {
dh=$(( $diff / 3600 ))
bn=$(printf ${backstat[z]} | awk '{print $1}')
IFS=$'\n'
case ${ROTA[a]} in
     daily)
        case $((($diff >= $warn_daily && $diff <= $crit_daily) * 1 + ($diff >= $crit_daily ) * 2)) in
        1)
            warns+=($(printf "${bn} ${dh} \n"))
	    stat_warn=1
            ;;
        2)
            crits+=($(printf "${bn} ${dh} \n"))
	    stat_crit=2
            ;;
        esac
        ;;
     weekly)
        case $((($diff >= $warn_weekly && $diff <= $crit_weekly) * 1 + ($diff >= $crit_weekly ) * 2)) in
        1)
            warns+=($(printf "${bn} ${dh} \n"))
	    stat_warn=1
            ;;
        2)
            crits+=($(printf "${bn} ${dh} \n"))
	    stat_crit=2
            ;;
        esac
        ;;
    monthly)
        case $((($diff >= $warn_monthly && $diff <= $crit_monthly) * 1 + ($diff >= $crit_monthly ) * 2)) in
        1)
            warns+=($(printf "${bn} ${dh} \n"))
	    stat_warn=1
            ;;
        2)
            crits+=($(printf "${bn} ${dh} \n"))
	    stat_crit=2
            ;;
        esac
        ;;
esac
}

findo_and_sorto () {
	Z=0
	for ((a=0;a<${#ROTA[@]};a++))
	do
	    for ((b=0;b<${#backdirs[@]};b++))
		do
			fpath=${BACKDIR}${backdirs[b]}/${ROTA[a]}
			backstat+=($(find ${fpath} \
				-maxdepth 1 \
				-type d \
				-printf '%p %Cs\n' \
				2>/dev/null))
			[[ $? != 0 ]] && {
				backstat_nf+=($(printf "${fpath} not found! \n"))
			        backstat+=($(printf "${fpath} 1000000000 \n"))
				continue
			}
		done
		for ((z=$Z;z<${#backstat[@]};z++))
		do
			diff=$((${now} - $(printf ${backstat[z]} \
				| awk '{print $2}')))
			Z=$z
			checko
		done
	done
}

## functions for printing warnings und criticals gathered in prior for loop

findo_and_sorto
stat=$(($stat_warn+$stat_crit))
print_warns () {
for ((i=0;i<${#warns[@]};i++))
do
	printf "{$(awk '{print $1" is "$2" hours old!"}' \
		<(printf "${crits[i]}"))} "
done
}

print_crits () {
for ((i=0;i<${#crits[@]};i++))
do
	printf "{$(awk '{print $1" is "$2" hours old!"}' \
		<(printf "${crits[i]}"))} "
done
}

case ${stat} in
	1)
		${ECHO} -n "WARNING "
		print_warns
		exit 1
		;;
	2)	
		${ECHO} -n "CRITICAL "
		print_crits
		exit 2
		;;
	3)
		${ECHO} -n "CRITICAL "
		print_warns
		${ECHO} -n "WARNING "
		print_crits
		exit 2
		;;

	0)	${ECHO} "OK"
		exit 0
		;;
esac
