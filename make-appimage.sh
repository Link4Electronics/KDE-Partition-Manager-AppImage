#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q partitionmanager | awk '{print $2; exit}')
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/partitionmanager.svg
export DESKTOP=/usr/share/applications/org.kde.partitionmanager.desktop
export STARTUPWMCLASS=org.kde.partitionmanager
export USE_HOST_DRIVERS=1

# Deploy dependencies
quick-sharun /usr/bin/partitionmanager /usr/share/config.kcfg
quick-sharun --make-static-bin /usr/lib/kpmcore_externalcommand

mkdir -p ./AppDir/helper
cp -v /usr/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy ./AppDir/helper/policy
cp -v /usr/share/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf ./AppDir/helper/conf
pacman -Q kpmcore | awk '{print $2}' > ./AppDir/helper/version

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
