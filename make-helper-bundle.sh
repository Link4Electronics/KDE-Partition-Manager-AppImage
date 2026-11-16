#!/bin/sh

set -eu

appdir=${APPDIR:-./AppDir}
helper_src=$appdir/shared/bin/kpmcore_externalcommand
builddir=$appdir/onelf-helper
outbin=$appdir/bin/kpmcore_externalcommand
bundle=$appdir/helper-bundle
tarfile=$appdir/helper-bundle.tar
version=${KPMCORE_VERSION:-$(pacman -Q kpmcore | awk '{print $2}')}
policy=${KPM_POLICY:-/usr/share/polkit-1/actions/org.kde.kpmcore.externalcommand.policy}
conf=${KPM_CONF:-/usr/share/dbus-1/system.d/org.kde.kpmcore.helperinterface.conf}
arch=$(uname -m)

case "$arch" in
	x86_64)
		onelf_url=https://github.com/QaidVoid/onelf/releases/download/0.6.2/onelf-x86_64-linux
		onelf_sha=055810eb9a7df496b8442e6f6d6fc731ab4385154327b34464ae7aae941de17e
		;;
	aarch64)
		onelf_url=https://github.com/QaidVoid/onelf/releases/download/0.6.2/onelf-aarch64-linux
		onelf_sha=ab194577eb706acc846e99dd69ea77f78dd70f06ab12a4f0f0c25368031c07f2
		;;
	*)
		echo "Unsupported architecture: $arch" >&2
		exit 1
		;;
esac

onelf=${TMPDIR:-/tmp}/kpm-onelf
if [ ! -f "$onelf" ] || [ ! -x "$onelf" ]; then
	if command -v curl >/dev/null 2>&1; then
		curl -fL "$onelf_url" -o "$onelf"
	elif command -v wget >/dev/null 2>&1; then
		wget -O "$onelf" "$onelf_url"
	else
		echo "curl or wget is required" >&2
		exit 1
	fi
	chmod 755 "$onelf"
fi
echo "$onelf_sha  $onelf" | sha256sum -c - >/dev/null

rm -rf "$builddir" "$bundle" "$tarfile"
mkdir -p "$builddir/bin" "$builddir/lib"

cp -f "$helper_src" "$builddir/bin/kpmcore_externalcommand"

LD_LIBRARY_PATH=$appdir/lib ldd "$helper_src" |
	awk '/=> \// { print $3 } /^\// { print $1 }' |
	sort -u |
	while IFS= read -r lib; do
		case "$lib" in
			"$appdir"/lib/*) cp -Lf "$lib" "$builddir/lib/${lib##*/}" ;;
		esac
	done

ld=$(find "$appdir/lib" -maxdepth 1 -type f -name 'ld-linux*.so*' | head -n 1)
cp -Lf "$ld" "$builddir/lib/${ld##*/}"

"$onelf" pack "$builddir" -o "$outbin" --command bin/kpmcore_externalcommand
rm -rf "$builddir"

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
