#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
    btrfs-progs      \
    dosfstools       \
    exfatprogs       \
    f2fs-tools       \
    kvantum          \
    lxqt-qtplugin    \
    nilfs-utils      \
    ntfsprogs        \
    partitionmanager \
    qt6ct            \
    udftools         \
    xfsprogs

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano
