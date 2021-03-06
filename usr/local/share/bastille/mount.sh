#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille mount TARGET host_path container_path [filesystem_type options dump pass_number]${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -lt 2 ]; then
    usage
fi

TARGET=$1
shift

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(jls name)
else
    JAILS=$(jls name | awk "/^${TARGET}$/")
fi

if [ $# -eq 2 ]; then
    _fstab="$@ nullfs ro 0 0"
else
    _fstab="$@"
fi

## assign needed variables
_hostpath=$(echo "${_fstab}" | awk '{print $1}')
_jailpath=$(echo "${_fstab}" | awk '{print $2}')
_type=$(echo "${_fstab}" | awk '{print $3}')
_perms=$(echo "${_fstab}" | awk '{print $4}')
_checks=$(echo "${_fstab}" | awk '{print $5" "$6}')

## if any variables are empty, bail out
if [ -z "${_hostpath}" ] || [ -z "${_jailpath}" ] || [ -z "${_type}" ] || [ -z "${_perms}" ] || [ -z "${_checks}" ]; then
    echo -e "${COLOR_RED}FSTAB format not recognized.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Format: /host/path jail/path nullfs ro 0 0${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Read: ${_fstab}${COLOR_RESET}"
    exit 1
fi

## if host path doesn't exist or type is not "nullfs"
if [ ! -d "${_hostpath}" ] || [ "${_type}" != "nullfs" ]; then
    echo -e "${COLOR_RED}Detected invalid host path or incorrect mount type in FSTAB.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Format: /host/path jail/path nullfs ro 0 0${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Read: ${_fstab}${COLOR_RESET}"
    exit 1
fi

## if mount permissions are not "ro" or "rw"
if [ "${_perms}" != "ro" ] && [ "${_perms}" != "rw" ]; then
    echo -e "${COLOR_RED}Detected invalid mount permissions in FSTAB.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Format: /host/path jail/path nullfs ro 0 0${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Read: ${_fstab}${COLOR_RESET}"
    exit 1
fi

## if check & pass are not "0 0 - 1 1"; bail out
if [ "${_checks}" != "0 0" ] && [ "${_checks}" != "1 0" ] && [ "${_checks}" != "0 1" ] && [ "${_checks}" != "1 1" ]; then
    echo -e "${COLOR_RED}Detected invalid fstab options in FSTAB.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Format: /host/path jail/path nullfs ro 0 0${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Read: ${_fstab}${COLOR_RESET}"
    exit 1
fi

for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"

    ## aggregate variables into FSTAB entry
    _fstab_entry="${_hostpath} ${bastille_jailsdir}/${_jail}/root/${_jailpath} ${_type} ${_perms} ${_checks}"

    ## Create mount point if it does not exist. -- cwells
    if [ ! -d "${bastille_jailsdir}/${_jail}/root/${_jailpath}" ]; then
        if ! mkdir -p "${bastille_jailsdir}/${_jail}/root/${_jailpath}"; then
            echo -e "${COLOR_RED}Failed to create mount point inside jail.${COLOR_RESET}"
            exit 1
        fi
    fi

    ## if entry doesn't exist, add; else show existing entry
    if ! grep -q "${_jailpath}" "${bastille_jailsdir}/${_jail}/fstab" 2> /dev/null; then
        if ! echo "${_fstab_entry}" >> "${bastille_jailsdir}/${_jail}/fstab"; then
            echo -e "${COLOR_RED}Failed to create fstab entry: ${_fstab_entry}${COLOR_RESET}"
            exit 1
        fi
        echo "Added: ${_fstab_entry}"
    else
        grep "${_jailpath}" "${bastille_jailsdir}/${_jail}/fstab"
    fi
    mount -F "${bastille_jailsdir}/${_jail}/fstab" -a
    echo
done
