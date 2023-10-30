#!/bin/sh -e

HOSTNAME="saigo"

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup exit

mkdir -p "$tmp"/etc
mkdir -p "$tmp"/etc/apk
mkdir -p "$tmp"/etc/network
mkdir -p "$tmp"/root

cp ~/aports/scripts/wallpaper.png "$tmp"/etc/wallpaper.png
cp ~/aports/scripts/tint2.tar.gz "$tmp"/etc/tint2.tar.gz
cp ~/aports/scripts/openbox.tar.gz "$tmp"/etc/openbox.tar.gz

makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
xorg-server
xf86-input-libinput
eudev
mesa-dri-gallium
openbox
xterm
font-noto
xf86-video-fbdev
xf86-video-vesa
xf86-video-nouveau
xf86-video-intel
xf86-input-vmmouse
xf86-input-synaptics
xf86-input-evdev
feh
tint2
alsa-utils
alsaconf
pulseaudio
pulseaudio-utils
pavucontrol-qt
agetty
picom
flatpak
EOF

makefile root:root 0755 "$tmp"/etc/inittab <<EOF
# /etc/inittab

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

tty1::respawn:/sbin/agetty 38400 tty1 --autologin root --noclear
tty2::respawn:/sbin/getty 38400 tty2

::shutdown:/sbin/openrc shutdown

ttyS0::respawn:/sbin/getty -L 0 ttyS0 vt100
EOF

makefile root:root 0755 "$tmp"/etc/.xinitrc <<EOF
pulseaudio --daemon --system &
feh --bg-fill /etc/wallpaper.png &
picom -c &
tint2 &
exec openbox-session
EOF

makefile root:root 0755 "$tmp"/etc/.profile <<EOF
#!/bin/sh -e

startx
EOF

makefile root:root 0755 "$tmp"/etc/setup-alpine <<'EOF'
#!/bin/sh

PROGRAM=setup-alpine
VERSION=@VERSION@

PREFIX=@PREFIX@
: ${LIBDIR=$PREFIX/lib}
. "$LIBDIR/libalpine.sh"

is_kvm_clock() {
	grep -q "kvm-clock"  "$ROOT"sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null
}

is_virtual_console() {
	case "$(readlink "$ROOT"/proc/self/fd/0)" in
		/dev/tty[0-9]*) return 0;;
	esac
	return 1
}

usage() {
	cat <<-__EOF__
		usage: setup-alpine [-ahq] [-c FILE | -f FILE]

		Setup Alpine Linux

		options:
		 -a  Create Alpine Linux overlay file
		 -c  Create answer file (do not install anything)
		 -e  Empty root password
		 -f  Answer file to use installation
		 -h  Show this help
		 -q  Quick mode. Ask fewer questions.
	__EOF__
	exit $1
}

while getopts "aef:c:hq" opt ; do
	case $opt in
		a) ARCHIVE=yes;;
		f) USEANSWERFILE="$OPTARG";;
		c) CREATEANSWERFILE="$OPTARG";;
		e) empty_root_password=1;;
		h) usage 0;;
		q) empty_root_password=1; quick=1; APKREPOSOPTS="-1"; HOSTNAMEOPTS="alpine";;
		'?') usage "1" >&2;;
	esac
done
shift $(expr $OPTIND - 1)

rc_sys=$(openrc --sys)
# mount xenfs so we can detect xen dom0
if [ "$rc_sys" = "XENU" ] && ! grep -q '^xenfs' /proc/mounts; then
	modprobe xenfs
	mount -t xenfs xenfs /proc/xen
fi

case "$USEANSWERFILE" in
	http*://*|ftp://*)
		# dynamically download answer file from URL (supports HTTP(S) and FTP)
		# ensure the network is up, otherwise setup a temporary interface config
		if ! rc-service networking --quiet status; then
			setup-interfaces -ar
		fi

		temp="$(mktemp)"
		wget -qO "$temp" "$USEANSWERFILE" || die "Failed to download '$USEANSWERFILE'"
		USEANSWERFILE="$temp"
		;;
	*)
		[ -n "$USEANSWERFILE" ] && USEANSWERFILE=$(realpath "$USEANSWERFILE")
		;;
esac
if [ -n "$USEANSWERFILE" ] && [ -e "$USEANSWERFILE" ]; then
	. "$USEANSWERFILE"
fi

if [ -n "$CREATEANSWERFILE" ]; then
	touch "$CREATEANSWERFILE" || echo "Cannot touch file $CREATEANSWERFILE"
	cat > "$CREATEANSWERFILE" <<-__EOF__
		# Example answer file for setup-alpine script
		# If you don't want to use a certain option, then comment it out

		# Use US layout with US variant
		# KEYMAPOPTS="us us"
		KEYMAPOPTS=none

		# Set hostname to 'alpine'
		HOSTNAMEOPTS=alpine

		# Set device manager to mdev
		DEVDOPTS=mdev

		# Contents of /etc/network/interfaces
		INTERFACESOPTS="auto lo
		iface lo inet loopback

		auto eth0
		iface eth0 inet dhcp
		    hostname alpine-test
		"

		# Search domain of example.com, Google public nameserver
		# DNSOPTS="-d example.com 8.8.8.8"

		# Set timezone to UTC
		#TIMEZONEOPTS="UTC"
		TIMEZONEOPTS=none

		# set http/ftp proxy
		#PROXYOPTS="http://webproxy:8080"
		PROXYOPTS=none

		# Add first mirror (CDN)
		APKREPOSOPTS="-1"

		# Create admin user
		USEROPTS="-a -u -g audio,video,netdev juser"
		#USERSSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIiHcbg/7ytfLFHUNLRgEAubFz/13SwXBOM/05GNZe4 juser@example.com"
		#USERSSHKEY="https://example.com/juser.keys"

		# Install Openssh
		SSHDOPTS=openssh
		#ROOTSSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIiHcbg/7ytfLFHUNLRgEAubFz/13SwXBOM/05GNZe4 juser@example.com"
		#ROOTSSHKEY="https://example.com/juser.keys"

		# Use openntpd
		# NTPOPTS="openntpd"
		NTPOPTS=none

		# Use /dev/sda as a sys disk
		# DISKOPTS="-m sys /dev/sda"
		DISKOPTS=none

		# Setup storage with label APKOVL for config storage
		#LBUOPTS="LABEL=APKOVL"
		LBUOPTS=none

		#APKCACHEOPTS="/media/LABEL=APKOVL/cache"
		APKCACHEOPTS=none

	__EOF__
	echo "Answer file $CREATEANSWERFILE has been created.  Please add or remove options as desired in that file"
	exit 0
fi

if [ "$ARCHIVE" ] ; then
	echo "Creating an Alpine overlay"
	init_tmpdir ROOT
else
	PKGADD="apk add"
fi

if [ "$rc_sys" != LXC ]; then
	if is_virtual_console || [ -n "$KEYMAPOPTS" ]; then
		setup-keymap ${KEYMAPOPTS}
	fi
	setup-hostname ${HOSTNAMEOPTS} && [ -z "$SSH_CONNECTION" ] && rc-service hostname --quiet restart
	setup-devd -C mdev # just to bootstrap
fi

[ -z "$SSH_CONNECTION" ] && rst_if=1
if [ -n "$INTERFACESOPTS" ]; then
	if [ "$INTERFACESOPTS" != none ]; then
		printf "$INTERFACESOPTS" | setup-interfaces -i ${rst_if:+-r}
	fi
else
	setup-interfaces ${quick:+-a} ${rst_if:+-r}
fi

# setup up dns if no dhcp was configured
if [ -f "$ROOT"/etc/network/interfaces ] && ! grep -q '^iface.*dhcp' "$ROOT"/etc/network/interfaces; then
	setup-dns ${DNSOPTS}
fi

# set root password
if [ -z "$empty_root_password" ]; then
	while ! $MOCK passwd ; do
		echo "Please retry."
	done
fi

if [ -z "$quick" ]; then
	# pick timezone
	setup-timezone ${TIMEZONEOPTS}
fi

rc-update --quiet add networking boot
rc-update --quiet add seedrng boot || rc-update --quiet add urandom boot
svc_list="cron crond"
if [ -e /dev/input/event0 ]; then
	# Only enable acpid for systems with input events entries
	# https://gitlab.alpinelinux.org/alpine/aports/-/issues/12290
	svc_list="$svc_list acpid"
fi
for svc in $svc_list; do
	if rc-service --exists $svc; then
		rc-update --quiet add $svc
	fi
done

# start up the services
$MOCK openrc ${SSH_CONNECTION:+-n} boot
$MOCK openrc ${SSH_CONNECTION:+-n} default

# update /etc/hosts - after we have got dhcp address
# Get default fully qualified domain name from *first* domain
# given on *last* search or domain statement.
_dn=$(sed -n \
-e '/^domain[[:space:]][[:space:]]*/{s///;s/\([^[:space:]]*\).*$/\1/;h;}' \
-e '/^search[[:space:]][[:space:]]*/{s///;s/\([^[:space:]]*\).*$/\1/;h;}' \
-e '${g;p;}' "$ROOT"/etc/resolv.conf 2>/dev/null)

_hn=$(hostname)
_hn=${_hn%%.*}

sed -i -e "s/^127\.0\.0\.1.*/127.0.0.1\t${_hn}.${_dn:-$(get_fqdn my.domain)} ${_hn} localhost.localdomain localhost/" \
	"$ROOT"/etc/hosts 2>/dev/null

if [ -z "$quick" ]; then
	setup-proxy -q ${PROXYOPTS}
fi
# activate the proxy if configured
if [ -r "$ROOT/etc/profile" ]; then
	. "$ROOT/etc/profile"
fi

if ! is_kvm_clock && [ "$rc_sys" != "LXC" ] && [ "$quick" != 1 ]; then
	setup-ntp ${NTPOPTS}
fi

setup-apkrepos ${APKREPOSOPTS}

# Now that network and apk are operational we can install another device manager
if [ "$rc_sys" != LXC ] && [ -n "$DEVDOPTS" -a "$DEVDOPTS" != mdev ]; then
	setup-devd ${DEVDOPTS}
fi

# lets stop here if in "quick mode"
if [ "$quick" = 1 ]; then
	exit 0
fi

setup-user -f 'User' -a -g 'audio video netdev' user

setup-sshd ${ROOTSSHKEY+-k "$ROOTSSHKEY"} ${SSHDOPTS}
root_keys="$ROOT"/root/.ssh/authorized_keys
if [ -f "$root_keys" ]; then
	lbu add "$ROOT"/root
fi

if is_xen_dom0; then
	setup-xen-dom0
fi

if [ "$rc_sys" = "LXC" ]; then
	exit 0
fi

DEFAULT_DISK=none \
	setup-disk -w /tmp/alpine-install-diskmode.out -q ${DISKOPTS} || exit

diskmode=$(cat /tmp/alpine-install-diskmode.out 2>/dev/null)

# setup lbu and apk cache unless installed sys on disk
if [ "$diskmode" != "sys" ]; then
	setup-lbu ${LBUOPTS}
	setup-apkcache ${APKCACHEOPTS}
	if [ -L "$ROOT"/etc/apk/cache ]; then
		apk cache sync
	fi
fi
EOF

makefile root:root 0755 "$tmp"/etc/setup.sh <<EOF
mkdir -p /root/.config
tar -xzvf /etc/tint2.tar.gz -C /root/.config
tar -xzvf /etc/openbox.tar.gz -C /root/.config

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

mv /etc/setup-alpine /sbin/setup-alpine
chmod +x /sbin/setup-alpine
cp /etc/.xinitrc /root/
cp /etc/.profile /root/
/root/.profile
EOF

makefile root:root 0644 "$tmp"/etc/motd <<EOF
Welcome to SaigOS!
EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add udev boot
rc_add dbus boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
