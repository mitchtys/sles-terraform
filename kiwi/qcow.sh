#!/usr/bin/env sh
#-*-mode: Shell-script; coding: utf-8;-*-
_base=$(basename "$0")
_dir=$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P || exit 126)
export _base _dir

action=$1
shift
dest=$1
shift
uri=$1
shift

# dest="boot.qcow2"
# uri="http://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-OpenStack-Cloud.qcow2"

update=no
localsha=""
remotesha=""

if [ "${action}" = "create" ] || [ "${action}" = "update" ]; then
    if [ -f "${dest}" ]; then
      localsha=$(sha256sum boot.qcow2 | awk '{print $1}')
      remotesha=$(curl -sL "${uri}.sha256" |awk '{print $1}')

      if [ "${localsha}" != "${remotesha}" ]; then
        printf "sha %s != %s\n" "${localsha}" "${remotesha}" >&2
        update=yes
      fi
    else
      printf "%s missing will download\n" "${dest}" >&2
      update=yes
    fi
fi

if [ "${update}" = "yes" ]; then
  curl -sL -o "${dest}" "${uri}"
fi

if [ "${action}" != "delete" ]; then
#   rm -fr "${dest}"
# else
  sha256sum boot.qcow2 | awk '{print $1}'
fi
