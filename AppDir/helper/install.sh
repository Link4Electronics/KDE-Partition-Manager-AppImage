#!/bin/sh
# Install the static KPMcore helper root-owned.

set -e

src=$(dirname "$0")
dst=/usr/local/lib/kpm-appimage

mkdir -p "$dst"
cp -f "$src/kpmcore_externalcommand" "$dst/kpmcore_externalcommand"
chmod 755 "$dst/kpmcore_externalcommand"
cp -f "$src/version" "$dst/version"

if ! cp -f "$src/policy" /usr/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy 2>/dev/null; then
	mkdir -p /usr/local/share/polkit-1/actions
	cp -f "$src/policy" /usr/local/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy
fi

if ! cp -f "$src/conf" /etc/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf 2>/dev/null; then
	mkdir -p /usr/share/dbus-1/system.d
	cp -f "$src/conf" /usr/share/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf
fi

mkdir -p /usr/local/share/dbus-1/system-services
cp -f "$src/service" /usr/local/share/dbus-1/system-services/org.kde.kpmcore.helperinterface.service

if command -v dbus-send >/dev/null 2>&1; then
	dbus-send --system --type=signal / org.freedesktop.DBus.ReloadConfig >/dev/null 2>&1 || :
fi
if command -v systemctl >/dev/null 2>&1; then
	systemctl reload dbus 2>/dev/null || systemctl reload dbus-broker 2>/dev/null || :
fi
