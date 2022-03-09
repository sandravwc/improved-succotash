#!/usr/bin/env bash

ENV=$(which env)
WHICH=$(${ENV} which which)
GREP=$(${WHICH} grep)
UNAME=$(${WHICH} uname)
ECHO=$(${WHICH} echo)
CP=$(${WHICH} cp)
MKDIR=$(${WHICH} mkdir)
CHMOD=$(${WHICH} chmod)
SYSTEMCTL=$(${WHICH} systemctl)

timer () {
    ${CP} -ip systemd/multimysqlbackup.service /etc/systemd/system/
    ${CP} -ip systemd/multimysqlbackup.timer /etc/systemd/system
    ${SYSTEMCTL} start multimysqlbackup.timer
    ${SYSTEMCTL} enable multimysqlbackup.timer
}

cron () {
    ${ECHO} '30 4 * * * root /usr/bin/sh -c "/usr/local/bin/multimysqlbackup -c /usr/local/etc/ixsqlbackup.conf.d/multimysqlbackup.conf"' >> /etc/crontab
}

${CP} -ip ixsqlbackup.bash /usr/local/bin/ixsqlbackup
${CP} -ip multimysqlbackup.bash /usr/local/bin/multimysqlbackup
${CHMOD} +x /usr/local/bin/ixsqlbackup
${CHMOD} +x /usr/local/bin/multimysqlbackup

${MKDIR} /usr/local/etc/ixsqlbackup.conf.d
${CP} -ip ixsqlbackup.conf /usr/local/etc/ixsqlbackup.conf.d/ixsqlbackup.conf
${CP} -ip multimysqlbackup.conf /usr/local/etc/ixsqlbackup.conf.d/

if [[ ! $(${UNAME} -o | ${GREP} -i linux) ]] ; then
    cron
elif [[ $(${UNAME} -o | ${GREP} -i linux) ]] ; then
    timer
else
    ${ECHO} "bro check uname -o output"
fi