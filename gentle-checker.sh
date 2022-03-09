#!/usr/bin/env bash
# check_mysql_dumps
# do da check of how old my dumps are
# VER 3.0
# Upstream URL: https://gitlab.muc.internetx.com/p-s/rpm/ixsqlbackup
####################################################################################
####################################################################################
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/mysql/bin:/root/bin  ##
VER="3.0"                                                                         ##
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
            CONFPATH=$OPTARG;fopts=${fopts}+1 
            ;;
        b)
            BACKDIR=$OPTARG;fopts=${fopts}+1 
            ;;
        r)
            IFS=','
            # since we want correct word splitting
            # shellcheck disable=2206
            ROTA+=(${OPTARG});fopts=${fopts}+1
            unset IFS
            ;;
        h)
            HELP=1; fopts=0 
            ;;
        ?)
            ${ECHO} "excuse me?" 
            ;;
    esac
done

[[ ${HELP} == 1 ]] && help # exit asap if "help was needed"

[[ ! ${CONFPATH} ]] && CONFPATH="/usr/local/etc/multimysqlbackup.d"
[[ ! ${BACKDIR} ]] && BACKDIR="/backup/mysql"
IFS=$'\n'
day=$((60**2*24))
week=$((day*7))
month=$((day*30))
warn_daily=$day 
[[ ${DDOM} == 1 && $(${DATEC} --date='-1 day' +%u) == 1 ]] && warn_daily=$((day*2))
[[ ${DOW} == 1 && $((10#$(${DATEC} --date='-1 day' +%d))) == 1 ]] && warn_daily=$((day*2))
crit_daily=$((warn_daily + day))
warn_weekly=$((week + day))
# sc doesnt know, but crrot and wrrot do get used 
# shellcheck disable=2034
crit_weekly=$((warn_weekly + crit_daily))
warn_monthly=$((month + day))
# sc doesnt know 
# shellcheck disable=2034
crit_monthly=$((warn_monthly + crit_daily))
now=$(${DATEC} +'%s')
stat=0
stat_warn=0
stat_crit=0
# stuff i dont wanna touch 
if [[ ! -s /usr/local/psa/version ]] && [[ ! -s /etc/psa/.psa.shadow ]] ; then
    backdirs+=($(${AWK} -F ";" '{print $1}' <(${GREP} -Evhr "^#|^$" ${CONFPATH}) | ${AWK} -F ":" '{print $1}'))
elif [[ -s /usr/local/psa/version ]] && [[ -s /etc/psa/.psa.shadow ]] ; then
    backdirs+=($(${ECHO} localhost))
fi
# check
Z=0
for ((a=0;a<${#ROTA[@]};a++))
do
    wrrot=$(eval printf '$warn_'"${ROTA[a]}")
    crrot=$(eval printf '$crit_'"${ROTA[a]}")
    for ((b=0;b<${#backdirs[@]};b++))
    do
        fpath=${BACKDIR}${backdirs[b]}/${ROTA[a]}
        # once again we took care of word splitting by setting IFS
        # shellcheck disable=SC2207
        backstat+=($(find "${fpath}" \
            -maxdepth 1 \
            -type d \
            -printf '%p %Cs\n' \
            2>/dev/null))
        # its cleaner this way, trust me
        # shellcheck disable=2181
        [[ $? != 0 ]] && {
            backstat_nf+=("$(printf "%s not found! \n" "${fpath}")")
            backstat+=("$(printf "%s 1000000000 \n" "${fpath}")")
            continue
        }
    done
    for ((z=Z;z<${#backstat[@]};z++))
    do   
        tdiff=$((now - $(printf "%s\n" "${backstat[z]}" \
            | awk '{print $2}')))
        dh=$((tdiff/3600))
        bn=$(printf "%s" "${backstat[z]}" \
            | awk '{print $1}' \
            | awk -F "/" '{for (i=4; i<NF; i++) printf $i "/"; print $NF}')
        case $((
            (tdiff >= wrrot && tdiff <= crrot) * 1 + 
            (tdiff >= crrot) * 2  
            )) in
                1)
                    warns+=("$(printf "%s\n" "${bn} ${dh}")")
                    stat_warn=1
                    ;;
                2)
                    crits+=("$(printf "%s\n" "${bn} ${dh}")")
                    stat_crit=2
                    ;;
        esac
        Z=$z
    done
done

print_warns () {
for ((i=0;i<${#warns[@]};i++))
do
    echo -n "{$(awk '{print $1" is "$2" hours old!"}' \
        <(printf "%s\n" "${warns[i]}"))} "
done
}

print_crits () {
for ((i=0;i<${#crits[@]};i++))
do
    echo -n "{$(awk '{print $1" is "$2" hours old!"}' \
        <(printf "%s\n" "${crits[i]}"))} "
done
}
stat=$((stat_warn+stat_crit))
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