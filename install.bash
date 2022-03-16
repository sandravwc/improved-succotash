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
    ${CP} -ip systemd/improved-succotash.service /etc/systemd/system/
    ${CP} -ip systemd/improved-succotash.timer /etc/systemd/system/
    ${SYSTEMCTL} start improved-succotash.timer
    ${SYSTEMCTL} enable improved-succotash.timer
}

cron () {
    ${ECHO} '30 4 * * * root /usr/bin/sh -c "/usr/local/bin/comfy-wrapper -c /usr/local/etc/improved-succotash.conf.d/comfy-wrapper.conf"' >> /etc/crontab
}

${CP} -ip improved-succotash.sh /usr/local/bin/improved-succotash
${CP} -ip comfy-wrapper.sh /usr/local/bin/comfy-wrapper
${CHMOD} +x /usr/local/bin/improved-succotash
${CHMOD} +x /usr/local/bin/comfy-wrapper

${MKDIR} /usr/local/etc/improved-succotash.conf.d
${CP} -ip improved-succotash.conf /usr/local/etc/
${CP} -ip comfy-wrapper.conf /usr/local/etc/ixsqlbackup.conf.d/

if [[ ! $(${UNAME} -o | ${GREP} -i linux) ]] ; then
    cron
elif [[ $(${UNAME} -o | ${GREP} -i linux) ]] ; then
    timer
else
    ${ECHO} "bro check uname -o output"
fi