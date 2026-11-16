#!/bin/sh

set -eu

appdir=${APPDIR:-./AppDir}
helper_src=$appdir/shared/bin/kpmcore_externalcommand
outbin=$appdir/bin/kpmcore_externalcommand
bundle=$appdir/helper-bundle
tarfile=$appdir/helper-bundle.tar
version=${KPMCORE_VERSION:-$(pacman -Q kpmcore | awk '{print $2}')}
policy=${KPM_POLICY:-/usr/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy}
conf=${KPM_CONF:-/usr/share/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf}

rm -rf "$bundle" "$tarfile"

APPDIR=$appdir quick-sharun --make-static-bin "$helper_src"

mkdir -p "$bundle"
cp -f "$outbin" "$bundle/kpmcore_externalcommand"
cp -f "$policy" "$bundle/policy"
cp -f "$conf" "$bundle/conf"

cat <<-EOF > "$bundle/service"
	[D-BUS Service]
	Name=org.kde.kpmcore.helperinterface
	Exec=env ONELF_MODE=rundir /usr/local/lib/kpm-appimage/kpmcore_externalcommand
	User=root
EOF

cat <<-EOF > "$bundle/install.sh"
	#!/bin/sh
	set -e
	bundle=/usr/local/lib/kpm-appimage
	if ! cp -f "\$bundle"/policy /usr/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy 2>/dev/null; then
		mkdir -p /usr/local/share/polkit-1/actions
		cp -f "\$bundle"/policy /usr/local/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy
	fi
	if ! cp -f "\$bundle"/conf /etc/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf 2>/dev/null; then
		mkdir -p /usr/share/dbus-1/system.d
		cp -f "\$bundle"/conf /usr/share/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf
	fi
	mkdir -p /usr/local/share/dbus-1/system-services
	cp -f "\$bundle"/service /usr/local/share/dbus-1/system-services/org.kde.kpmcore.helperinterface.service
	if command -v dbus-send >/dev/null 2>&1; then
		dbus-send --system --type=signal / org.freedesktop.DBus.ReloadConfig >/dev/null 2>&1 || :
	fi
	if command -v systemctl >/dev/null 2>&1; then
		systemctl reload dbus 2>/dev/null || systemctl reload dbus-broker 2>/dev/null || :
	fi
EOF
chmod 755 "$bundle/install.sh"

echo "$version" > "$bundle/version"
cp -f "$bundle/version" "$appdir/helper-bundle.version"

tar --owner=0 --group=0 --numeric-owner -C "$bundle" -cf "$tarfile" .
rm -rf "$bundle"
