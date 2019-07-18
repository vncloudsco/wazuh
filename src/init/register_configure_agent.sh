#!/bin/sh

# Copyright (C) 2015-2019, Wazuh Inc.
# March 6, 2019.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

. /etc/ossec-init.conf

sed="sed -ri"
# By default, use gnu sed (gsed).
use_unix_sed="False"

unix_sed() {
    sed_expression="$1"
    target_file="$2"

    sed "${sed_expression}" "${target_file}" > "${target_file}.tmp"
    cat "${target_file}.tmp" > "${target_file}"
    rm "${target_file}.tmp"
}

edit_value_tag() {

    if [ ! -z "$1" ] && [ ! -z "$2" ]; then
        if [ "${use_unix_sed}" = "False" ] ; then
            ${sed} "s#<$1>.*</$1>#<$1>$2</$1>#g" "${DIRECTORY}/etc/ossec.conf"
        else
            unix_sed "s#<$1>.*</$1>#<$1>$2</$1>#g" "${DIRECTORY}/etc/ossec.conf"
        fi
    fi

    if [ $? != 0 ] ; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') agent-auth: Error updating $2 with variable $1." >> ${DIRECTORY}/logs/ossec.log
    fi
}

add_adress_block() {

    SET_ADDRESSES="$@"

    # Remove the server configuration
    if [ "${use_unix_sed}" = "False" ] ; then
        ${sed} "/<server>/,/\/server>/d" ${DIRECTORY}/etc/ossec.conf
    else
        unix_sed "/<server>/,/\/server>/d" "${DIRECTORY}/etc/ossec.conf"
    fi

    # Get the client configuration generated by gen_ossec.sh
    start_config="$(grep -n "<client>" ${DIRECTORY}/etc/ossec.conf | cut -d':' -f 1)"
    end_config="$(grep -n "</client>" ${DIRECTORY}/etc/ossec.conf | cut -d':' -f 1)"
    start_config=$(( start_config + 1 ))
    end_config=$(( end_config - 1 ))
    client_config="$(sed -n "${start_config},${end_config}p" ${DIRECTORY}/etc/ossec.conf)"

    # Remove the client configuration
    if [ "${use_unix_sed}" = "False" ] ; then
        ${sed} "/<client>/,/\/client>/d" ${DIRECTORY}/etc/ossec.conf
    else
        unix_sed "/<client>/,/\/client>/d" "${DIRECTORY}/etc/ossec.conf"
    fi

    # Write the client configuration block
    echo "<ossec_config>" >> ${DIRECTORY}/etc/ossec.conf
    echo "  <client>" >> ${DIRECTORY}/etc/ossec.conf
    for i in ${SET_ADDRESSES};
    do
        echo "    <server>" >> ${DIRECTORY}/etc/ossec.conf
        echo "      <address>$i</address>" >> ${DIRECTORY}/etc/ossec.conf
        echo "      <port>1514</port>" >> ${DIRECTORY}/etc/ossec.conf
        echo "      <protocol>udp</protocol>" >> ${DIRECTORY}/etc/ossec.conf
        echo "    </server>" >> ${DIRECTORY}/etc/ossec.conf
    done

    echo "${client_config}" >> ${DIRECTORY}/etc/ossec.conf
    echo "  </client>" >> ${DIRECTORY}/etc/ossec.conf
    echo "</ossec_config>" >> ${DIRECTORY}/etc/ossec.conf
}

add_parameter () {
    if [ ! -z "$3" ]; then
        OPTIONS="$1 $2 $3"
    fi
    echo ${OPTIONS}
}

set_vars () {
    export WAZUH_MANAGER_IP=$(launchctl getenv WAZUH_MANAGER_IP)
    export WAZUH_PROTOCOL=$(launchctl getenv WAZUH_PROTOCOL)
    export WAZUH_MANAGER_PORT=$(launchctl getenv WAZUH_MANAGER_PORT)
    export WAZUH_NOTIFY_TIME=$(launchctl getenv WAZUH_NOTIFY_TIME)
    export WAZUH_TIME_RECONNECT=$(launchctl getenv WAZUH_TIME_RECONNECT)
    export WAZUH_AUTHD_SERVER=$(launchctl getenv WAZUH_AUTHD_SERVER)
    export WAZUH_AUTHD_PORT=$(launchctl getenv WAZUH_AUTHD_PORT)
    export WAZUH_PASSWORD=$(launchctl getenv WAZUH_PASSWORD)
    export WAZUH_AGENT_NAME=$(launchctl getenv WAZUH_AGENT_NAME)
    export WAZUH_GROUP=$(launchctl getenv WAZUH_GROUP)
    export WAZUH_CERTIFICATE=$(launchctl getenv WAZUH_CERTIFICATE)
    export WAZUH_KEY=$(launchctl getenv WAZUH_KEY)
    export WAZUH_PEM=$(launchctl getenv WAZUH_PEM)
}

unset_vars() {

    OS=$1

    vars="WAZUH_MANAGER_IP WAZUH_PROTOCOL WAZUH_MANAGER_PORT WAZUH_NOTIFY_TIME \
          WAZUH_TIME_RECONNECT WAZUH_AUTHD_SERVER WAZUH_AUTHD_PORT WAZUH_PASSWORD \
          WAZUH_AGENT_NAME WAZUH_GROUP WAZUH_CERTIFICATE WAZUH_KEY WAZUH_PEM"


    for var in ${vars}; do
        if [ "${OS}" = "Darwin" ]; then
            launchctl unsetenv ${var}
        fi
        unset ${var}
    done
}

tolower () {
   echo $1 | tr '[:upper:]' '[:lower:]'
}

main () {

    uname_s=$(uname -s)

    if [ "${uname_s}" = "Darwin" ]; then
        sed="sed -ire"
        set_vars
    elif [ "${uname_s}" = "AIX" ] || [ "${uname_s}" = "SunOS" ] || [ "${uname_s}" = "HP-UX" ]; then
        use_unix_sed="True"
    fi

    if [ ! -s ${DIRECTORY}/etc/client.keys ] && [ ! -z "${WAZUH_MANAGER_IP}" ]; then
        if [ ! -f ${DIRECTORY}/logs/ossec.log ]; then
            touch -f ${DIRECTORY}/logs/ossec.log
            chmod 660 ${DIRECTORY}/logs/ossec.log
            chown root:ossec ${DIRECTORY}/logs/ossec.log
        fi

        # Check if multiples IPs are defined in variable WAZUH_MANAGER_IP
        ADDRESSES="$(echo ${WAZUH_MANAGER_IP} | awk '{split($0,a,",")} END{ for (i in a) { print a[i] } }' |  tr '\n' ' ')"
        if echo ${ADDRESSES} | grep ' ' > /dev/null 2>&1 ; then
            # Get uniques values
            ADDRESSES=$(echo "${ADDRESSES}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
            add_adress_block "${ADDRESSES}"
            if [ -z "${WAZUH_AUTHD_SERVER}" ]; then
                WAZUH_AUTHD_SERVER=$(echo ${WAZUH_MANAGER_IP} | cut -d' ' -f 1)
            fi
        else
            # Single address
            edit_value_tag "address" ${WAZUH_MANAGER_IP}
            if [ -z "${WAZUH_AUTHD_SERVER}" ]; then
                WAZUH_AUTHD_SERVER=${WAZUH_MANAGER_IP}
            fi
        fi

        # Options to be modified in ossec.conf
        edit_value_tag "protocol" "$(tolower ${WAZUH_PROTOCOL})"
        edit_value_tag "port" ${WAZUH_MANAGER_PORT}
        edit_value_tag "notify_time" ${WAZUH_NOTIFY_TIME}
        edit_value_tag "time-reconnect" ${WAZUH_TIME_RECONNECT}

    elif [ -s ${DIRECTORY}/etc/client.keys ] && [ ! -z "${WAZUH_MANAGER_IP}" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') agent-auth: ERROR: The agent is already registered." >> ${DIRECTORY}/logs/ossec.log
    fi

    if [ ! -s ${DIRECTORY}/etc/client.keys ] && [ ! -z "${WAZUH_AUTHD_SERVER}" ]; then
        # Options to be used in register time.
        OPTIONS="-m ${WAZUH_AUTHD_SERVER}"
        OPTIONS=$(add_parameter "${OPTIONS}" "-p" "${WAZUH_AUTHD_PORT}")
        OPTIONS=$(add_parameter "${OPTIONS}" "-P" "${WAZUH_PASSWORD}")
        OPTIONS=$(add_parameter "${OPTIONS}" "-A" "${WAZUH_AGENT_NAME}")
        OPTIONS=$(add_parameter "${OPTIONS}" "-G" "${WAZUH_GROUP}")
        OPTIONS=$(add_parameter "${OPTIONS}" "-v" "${WAZUH_CERTIFICATE}")
        OPTIONS=$(add_parameter "${OPTIONS}" "-k" "${WAZUH_KEY}")
        OPTIONS=$(add_parameter "${OPTIONS}" "-x" "${WAZUH_PEM}")
        ${DIRECTORY}/bin/agent-auth ${OPTIONS} >> ${DIRECTORY}/logs/ossec.log 2>/dev/null
    fi

    unset_vars ${uname_s}
}

main
