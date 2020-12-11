#!/bin/sh

################################################################################
# LOG FILE & VERBOSITY SETUP
################################################################################
VERBOSE=0
LOGFILE="build.log"

# CD to the script directory for safety
SCRIPT_DIR_ABS=$(dirname $(readlink -f $0))
cd "$SCRIPT_DIR_ABS"

dbg() {
  echo "$@" >> $LOGFILE_ABS
  [ "$VERBOSE" -eq "1" ] && echo "$@"
}

# First thing move logfile using relative paths
if [ -f "$LOGFILE" ]; then
  mv -f "$LOGFILE" "${LOGFILE}.old" > /dev/null 2>&1
fi

# Touch the (relative) logfile so readlink -f works well
touch "$LOGFILE"

LOGFILE_ABS="$(readlink -f $LOGFILE)"

# Proces non-build switches (must be first)
while :; do
  case "$1" in
    -h|-\?|--help)
      echo "Help not implemented"
      exit
    ;;
    -v|--verbose)
      VERBOSE=1
    ;;
    *)
      break
    ;;
  esac
  shift
done

################################################################################
# CORE CONFIGURATION (device & version)
################################################################################
DEVICE="ubnt-erx"

# Version dir containing the imagebuilder (relative to script or absolute)
VER="19.07.5"

# NOTE: script assumes this is JUST a directory name
VERDIR="openwrt-imagebuilder-${VER}-ramips-mt7621.Linux-x86_64"

# Target string (for custom packages generation)
# TODO: would be safer to capture this from repositories.conf (e.g. from the base entry)
PKG_TARGET="mipsel_24kc"

################################################################################
# OVERRIDES CONFIGURATION (files & packages)
################################################################################
# Additional files directory
ADDFILES="my_files_erx"

# Add custom package repos
CUSTPKG_DIR="$SCRIPT_DIR_ABS/custom_packages/$PKG_TARGET"

rm prepend.tmp > /dev/null 2>&1
touch prepend.tmp

if [ -d $CUSTPKG_DIR ]; then
  for pkgdir in $CUSTPKG_DIR/*/; do
    if ! grep -qs "$pkgdir" "$VERDIR/repositories.conf"; then
      repo_name="${pkgdir#$CUSTPKG_DIR}"
      tmp="$repo_name/"
      while [ "$repo_name" != "$tmp" ]; do
        repo_name="$tmp"
        tmp="${tmp#/}"
        tmp="${tmp%/}"
      done
      echo "src custom_$repo_name file://$pkgdir" >> prepend.tmp
    fi
  done
fi

# See if the file needs updated
if [ $(wc -l < prepend.tmp) -ne 0 ]; then
  # Backup the original file
  cp "$VERDIR/repositories.conf" "$VERDIR/repositories.conf.bak"

  # Add an extra newline to the prepend to break sections
  echo "" >> prepend.tmp

  # Put the existing repositories.conf after prepend
  cat "$VERDIR/repositories.conf" >> prepend.tmp

  # Now start repositories.conf over with our auto-add comment
  # Note: this is dumb and just keeps adding the auto-add comment
  echo "# Auto-added custom package repos" > "$VERDIR/repositories.conf"

  cat prepend.tmp >> "$VERDIR/repositories.conf"
fi

rm prepend.tmp

################################################################################
# PACKAGE CONFIGURATION (packages & switch selection of packages)
################################################################################
PPPOE_PACKAGES="-ppp -ppp-mod-pppoe"
LUCI_PACKAGES="uhttpd uhttpd-mod-ubus libiwinfo-lua luci-base luci-app-firewall luci-mod-admin-full luci-theme-bootstrap"

# Then use my default config OR process build switches
if [ -z "$1" ]; then
  # Use OpenSSL and OpenSSH
  PACKAGES="$PACKAGES $PPPOE_PACKAGES $LUCI_PACKAGES luci-ssl-openssl -dropbear openssh-client openssh-server openvpn-openssl"
  # Luci-apps
  PACKAGES="$PACKAGES luci-app-acme luci-app-ddns luci-app-openvpn luci-app-upnp luci-app-wireguard luci-app-wol acme-dnsapi"
  # Shell CMD tools"
  PACKAGES="$PACKAGES diffutils git git-http htop nano"
  # User management commands
  PACKAGES="$PACKAGES sudo shadow-groupadd shadow-groupdel shadow-groupmems shadow-groupmod shadow-useradd shadow-userdel shadow-usermod"
  # Text editing tools
  PACKAGES="$PACKAGES vim less"
else
  while :; do
    case "$1" in
      --no-router)
        PACKAGES="$PACKAGES -dnsmasq -luci-app-firewall -firewall -iptables -odhcpd -odhcpd-ipv6only"
      ;;
      --keep-pppoe)
        PPPOE_PACKAGES=""
      ;;
      --no-ipv6)
        PACKAGES="$PACKAGES -ip6tables -odhcp6c -kmod-ipv6 -kmod-ip6tables -odhcpd-ipv6only"
      ;;
      --no-luci)
        LUCI_PACKAGES=""
      ;;
      --luci-mbedtls|--luci-ssl)
        LUCI_PACKAGES="$LUCI_PACKAGES luci-ssl"
      ;;
      --luci-openssl)
        LUCI_PACKAGES="$LUCI_PACKAGES luci-ssl-openssl"
      ;;
      --)
        shift
        break
      ;;
      --*)
        echo "Unrecognized switch '$1', use '--' to pass switches to the make command"
        exit
      ;;
      -p)
        PACKAGES="$PACKAGES -$2"
        shift
      ;;
      +p)
        PACKAGES="$PACKAGES $2"
        shift
      ;;
      '')
        break
      ;;
      *)
        echo "Unrecognized argument '$1', use '--' to pass switches to the make command"
        exit
      ;;
    esac
    shift
  done

  # Removals only work after includes, put LUCI first and PPPOE last
  PACKAGES="$LUCI_PACKAGES $PACKAGES $PPPOE_PACKAGES"
fi

################################################################################
# RUN BUILD
################################################################################
# Absorb the FILES switch into the variable to handle a lack of the directory
if [ -d "$ADDFILES" ]; then
  ln -sf "../$ADDFILES" "$VERDIR/"
  ADDFILES="FILES=$ADDFILES"
else
  ADDFILES=""
fi

dbg "~~~Build Config~~~"
dbg "Profile:\n  PROFILE=$DEVICE"
dbg "Additional Files:\n  ${ADDFILES#FILES=}"
dbg "Packages command:\n  PACKAGES='${PACKAGES# }'"
dbg "Extra switches:\n  $@"
dbg "\nRunning command:"
dbg "make image PROFILE=$DEVICE $ADDFILES PACKAGES="'"'"${PACKAGES# }"'"'" $@\n"

if [ "$VERBOSE" -eq "1" ]; then
  (cd $VERDIR && make image PROFILE=$DEVICE $ADDFILES PACKAGES="${PACKAGES# }" $@ 2>&1 | tee -a $LOGFILE_ABS)
else
  (cd $VERDIR && make image PROFILE=$DEVICE $ADDFILES PACKAGES="${PACKAGES# }" $@ >> $LOGFILE_ABS 2>&1)
fi

# IMPORTANT: we're already in VERDIR here

################################################################################
# CHECK RESULT & ATTEMPT FIX
################################################################################
if [ $? -eq 0 ]; then
  echo "Build completed successfully." | tee -a $LOGFILE_ABS
elif grep -q mismatch $LOGFILE_ABS; then
  # Ignore verbose for build fixing, print this to shell because the build needs re-run after cleanup
  echo "Build failed, possibly due to package mismatches. Cleaning the package cache." 2>&1 | tee -a $LOGFILE_ABS
  for f in $VERDIR/dl/openwrt_*; do
    zcat $f | sed -ne '/^Filename:/s/.* //p' -e '/^SHA256sum:/s/.* //p' | while read file; do
      read sum
      if [ -f "$VERDIR/dl/$file" ]; then
        sum1="$(sha256sum $VERDIR/dl/$file)"
        # Drop everything after the first space
        sum1="${sum1%% *}"
        if [ $sum != $sum1 ]; then
          echo "$file has been updated, removing the existing download" 2>&1 | tee -a $LOGFILE_ABS
          rm -f $VERDIR/dl/$file
        fi
      fi
    done
  done
  echo "Finished cleaning files. Please re-run the build script to try again." 2&>1 | tee -a $LOGFILE_ABS
else
  echo "Build failed for unknown reason. Please review $LOGFILE_ABS" 2>&1 | tee -a $LOGFILE_ABS
fi
