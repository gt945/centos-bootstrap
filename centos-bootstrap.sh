#!/bin/bash
#
# centos-bootstrap: Bootstrap a base Centos Linux system using any GNU distribution.
#
# Dependencies: bash >= 4, coreutils, wget, sed, gawk, tar, gzip, chroot, xz.
# Project: https://github.com/gt945/centos-bootstrap
#
# Install:
#
#   # install -m 755 centos-bootstrap.sh /usr/local/bin/centos-bootstrap
#
# Usage:
#
#   # centos-bootstrap destination
#   # centos-bootstrap -a x86_64 -r http://mirrors.tuna.tsinghua.edu.cn/centos destination-64
#   # centos-bootstrap -a aarch64 -r http://mirrors.tuna.tsinghua.edu.cn/centos-altarch destination
#
# And then you can chroot to the destination directory (user: root, password: root):
#
#   # chroot destination

set -e -u -o pipefail

# Packages needed by yum 
#
YUM_PACKAGES=(
    centos-release python python-libs nspr glibc rpm-python rpm yum  bzip2-libs elfutils-libelf  libacl libattr libcap libdb libselinux lua nss nss-util pcre popt rpm-libs xz-libs zlib python-iniparse python-urlgrabber pyxattr yum-metadata-parser yum-plugin-fastestmirror diffutils pygpgme pyliblzma glibc-common ncurses-libs rpm-build-libs file-libs nss-softokn sqlite nss-softokn-freebl openssl-libs krb5-libs  libcom_err keyutils-libs python-pycurl libcurl libidn libssh2 openldap cyrus-sasl-lib libffi glib2 libxml2 expat
)
BASIC_PACKAGES=(filesystem ${YUM_PACKAGES[*]})
EXTRA_PACKAGES=(@core @base redhat-lsb-core dracut-tools dracut-config-generic dracut-config-rescue)
DEFAULT_REPO_URL="http://mirror.centos.org/centos"
DEFAULT_ALT_REPO_URL="http://mirror.centos.org/altarch"

stderr() { 
  echo "$@" >&2 
}

debug() {
  stderr "--- $@"
}

extract_href() {
  sed -n '/<a / s/^.*<a [^>]*href="\([^\"]*\)".*$/\1/p'
}

fetch() {
  curl -L -s "$@"
}

fetch_file() {
  local FILEPATH=$1
  shift
  if [[ -e "$FILEPATH" ]]; then
    curl -L -z "$FILEPATH" -o "$FILEPATH" "$@"
  else
    curl -L -o "$FILEPATH" "$@"
  fi
}

uncompress() {
  local FILEPATH=$1 DEST=$2

  case "$FILEPATH" in
    *.rpm)
      rpm2cpio "$FILEPATH" | bsdtar -xf - -C "$DEST";;
    *.gz) 
      tar xzf "$FILEPATH" -C "$DEST";;
    *.xz) 
      xz -dc "$FILEPATH" | tar x -C "$DEST";;
    *) 
      debug "Error: unknown package format: $FILEPATH"
      return 1;;
  esac
}

###

get_default_repo() {
  local ARCH=$1
  if [[ "$ARCH" == arm*  || "$ARCH" == aarch64 ]]; then
    echo $DEFAULT_ALT_REPO_URL
  else
    echo $DEFAULT_REPO_URL
  fi
}

get_core_repo_url() {
  local REPO_URL=$1 ARCH=$2
  echo "${REPO_URL%/}/7/os/$ARCH/Packages"
}

configure_minimal_system() {
  local DEST=$1
  mkdir -p "$DEST/dev"
  cp "/etc/resolv.conf" "$DEST/etc/resolv.conf"
  sed -ie 's/^root:.*$/root:$1$GT9AUpJe$oXANVIjIzcnmOpY07iaGi\/:14657::::::/' "$DEST/etc/shadow"
  touch "$DEST/etc/group"
  echo "bootstrap" > "$DEST/etc/hostname"
  touch "$DEST/.autorelabel"
}

fetch_packages_list() {
  local REPO=$1

  debug "fetch packages list: $REPO/"
  fetch "$REPO/" | extract_href | awk -F"/" '{print $NF}' | sort -rn ||
    { debug "Error: cannot fetch packages list: $REPO"; return 1; }
}

install_yum_packages() {
  local BASIC_PACKAGES=$1 DEST=$2 LIST=$3 DOWNLOAD_DIR=$4
  debug "yum package and dependencies: $BASIC_PACKAGES"
  
  for PACKAGE in $BASIC_PACKAGES; do
    local FILE=$(echo "$LIST" | grep -m1 "^$PACKAGE-[[:digit:]].*\.rpm$")
    test "$FILE" || { debug "Error: cannot find package: $PACKAGE"; return 1; }
    local FILEPATH="$DOWNLOAD_DIR/$FILE"
    
    debug "download package: $REPO/$FILE"
    fetch_file "$FILEPATH" "$REPO/$FILE"
    debug "uncompress package: $FILEPATH"
    uncompress "$FILEPATH" "$DEST"
    rm "$FILEPATH"
  done
}

install_packages() {
  local ARCH=$1 DEST=$2 TARGET=$3 PACKAGES=$4
  debug "install packages: $PACKAGES"
  cp "/etc/resolv.conf" "$DEST/etc/resolv.conf"
  mkdir -p $DEST/mnt
  mkdir -p $DEST/dev
  mkdir -p $DEST/proc
  mkdir -p $DEST/sys
  mount --bind $TARGET $DEST/mnt
  mount --bind /dev/ $DEST/dev
  mount -t proc procfs $DEST/proc
  mount -t sysfs sysfs $DEST/sys
  LC_ALL=C chroot "$DEST" /usr/bin/yum \
    -y --installroot=/mnt --releasever=7 install $PACKAGES
  umount $DEST/mnt
  umount $DEST/dev
  umount $DEST/proc
  umount $DEST/sys
  
}

show_usage() {
  stderr "Usage: $(basename "$0") [-a i686|x86_64|arm|aarch64] [-r REPO_URL] [-d DOWNLOAD_DIR] DESTDIR"
}

main() {
  # Process arguments and options
  test $# -eq 0 && set -- "-h"
  local ARCH=
  local REPO_URL=
  local DOWNLOAD_DIR=
  local PRESERVE_DOWNLOAD_DIR=
  
  while getopts "qa:r:d:h" ARG; do
    case "$ARG" in
      a) ARCH=$OPTARG;;
      r) REPO_URL=$OPTARG;;
      d) DOWNLOAD_DIR=$OPTARG
         PRESERVE_DOWNLOAD_DIR=true;;
      *) show_usage; return 1;;
    esac
  done
  shift $(($OPTIND-1))
  test $# -eq 1 || { show_usage; return 1; }
  
  [[ -z "$ARCH" ]] && ARCH=$(uname -m)
  [[ -z "$REPO_URL" ]] &&REPO_URL=$(get_default_repo "$ARCH")
  
  local DEST=$1
  local REPO=$(get_core_repo_url "$REPO_URL" "$ARCH")
  [[ -z "$DOWNLOAD_DIR" ]] && DOWNLOAD_DIR=$(mktemp -d)
  mkdir -p "$DOWNLOAD_DIR"
  local DESTTMP=$(mktemp -d)
  [[ -z "$PRESERVE_DOWNLOAD_DIR" ]] && trap "rm -rf '$DOWNLOAD_DIR'" KILL TERM EXIT
  debug "destination directory: $DEST"
  debug "core repository: $REPO"
  debug "temporary directory: $DOWNLOAD_DIR"
  
  # Fetch packages, install system and do a minimal configuration
  mkdir -p "$DEST"
  mkdir -p "$DESTTMP"
  local LIST=$(fetch_packages_list $REPO)

  install_yum_packages "${YUM_PACKAGES[*]}" "$DESTTMP" "$LIST" "$DOWNLOAD_DIR"

  install_packages "$ARCH" "$DESTTMP" "$DEST" "${BASIC_PACKAGES[*]} ${EXTRA_PACKAGES[*]}"
  configure_minimal_system "$DEST"
  
  [[ -z "$PRESERVE_DOWNLOAD_DIR" ]] && rm -rf "$DOWNLOAD_DIR"
  
  debug "Done!"
  debug 
  debug "You can chroot now:"
  debug "$ sudo chroot $DEST"
}

main "$@"
