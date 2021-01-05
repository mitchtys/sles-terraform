#!/usr/bin/env sh
#-*-mode: Shell-script; coding: utf-8;-*-
#
# Effectively a wrapper around curl+sha256sum to handle:
# - iff downloading a thing, look for thing.sha256 file remotely
# - iff destination file exists, create/update/look for a sha256 file as well
# - iff the .sha256 file exists and is older than the destination file update it
# - iff the remote sha256 disagrees with the local sha256, update/download the file again and fix the .sha256 file locally
# - the action var is there for terraform lifecycle management
#
# To short circuit any work, you can define the following env var:
# - DL_DO_NOTHING=anything really as long as its defined
_base=$(basename "$0")
_dir=$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P || exit 126)
export _base _dir
set -eux

action=$1
shift
dest=$1
shift
uri=$1
shift

# if [ -n $DL_DO_NOTHING ]; then
#   printf "warn: DL_DO_NOTHING was set, not updating or validating local file %s from source %s\n" "${dest}" "${uri}"
#   exit 0
# fi

download=no
localsha=""
remotesha=""
destshafile="${dest}.sha256"
localsha=""

update_localshasum() {
  dest=$1
  shift
  shafile=$1

  if [ ! -f "${shafile}" ] || [ "${dest}" -nt "${shafile}" ]; then
    sha256sum "${dest}" > "${shafile}"
  fi
  localsha=$(cat "${destshafile}" | awk '{print $1}')
}

if [ "${action}" = "create" ] || [ "${action}" = "update" ]; then
    if [ -f "${dest}" ]; then
      update_localshasum "${dest}" "${destshafile}"
      remotesha=$(curl -sL "${uri}.sha256" | awk '{print $1}')

      if [ "${localsha}" != "${remotesha}" ]; then
        printf "sha %s != %s\n" "${localsha}" "${remotesha}" >&2
        download=yes
      fi
    else
      printf "%s missing will download\n" "${dest}" >&2
      download=yes
    fi
fi

if [ "${download}" = "yes" ]; then
  echo curl -sL -o "${dest}" "${uri}"
fi

if [ "${action}" != "delete" ]; then
  update_localshasum "${dest}" "${destshafile}"
#   rm -fr "${dest}"
    # else
  printf "%s\n" "${localsha}"
fi
