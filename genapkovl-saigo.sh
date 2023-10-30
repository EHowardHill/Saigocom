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

makefile root:root 0755 "$tmp"/etc/setup-saigo.sh <<'EOF'
#!/bin/sh -e

PREFIX=@PREFIX@
: ${LIBDIR=$PREFIX/lib}
. "$LIBDIR/libalpine.sh"

USEROPTS="-a -u -g audio,video,netdev juser"

setup-hostname saigo
rc-service hostname --quiet restart

setup-keymap us us
setup-devd -C mdev
setup-timezone UTC
setup-dns 208.67.222.123

printf "auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
	hostname alpine-test" | setup-interfaces -i ${rst_if:+-r}

rc-update --quiet add networking boot
rc-update --quiet add seedrng boot || rc-update --quiet add urandom boot
svc_list="cron crond"

if [ -e /dev/input/event0 ]; then
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

_dn=$(sed -n \
-e '/^domain[[:space:]][[:space:]]*/{s///;s/\([^[:space:]]*\).*$/\1/;h;}' \
-e '/^search[[:space:]][[:space:]]*/{s///;s/\([^[:space:]]*\).*$/\1/;h;}' \
-e '${g;p;}' "$ROOT"/etc/resolv.conf 2>/dev/null)

_hn=$(hostname)
_hn=${_hn%%.*}

sed -i -e "s/^127\.0\.0\.1.*/127.0.0.1\t${_hn}.${_dn:-$(get_fqdn my.domain)} ${_hn} localhost.localdomain localhost/" \
	"$ROOT"/etc/hosts 2>/dev/null

setup-ntp openntpd
setup-apkrepos -1
setup-devd mdev
setup-user ${USERSSHKEY+-k "$USERSSHKEY"} ${USEROPTS:--a -g 'audio video netdev'}
for i in "$ROOT"home/*; do
	if [ -d "$i" ]; then
		lbu add $i
	fi
done

setup-disk -w /tmp/alpine-install-diskmode.out -q -m sys /dev/vda || exit

# setup lbu and apk cache unless installed sys on disk
if [ $(cat /tmp/alpine-install-diskmode.out 2>/dev/null) != "sys" ]; then
	setup-lbu LABEL=APKOVL
	setup-apkcache /media/LABEL=APKOVL/cache
	apk cache sync
fi
EOF

makefile root:root 0755 "$tmp"/etc/setup.sh <<EOF
mkdir -p /root/.config
tar -xzvf /etc/tint2.tar.gz -C /root/.config
tar -xzvf /etc/openbox.tar.gz -C /root/.config

INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
	hostname alpine-test
"

setup-timezone UTC
setup-dns 208.67.222.123
setup-devd udev
setup-keymap us us
setup-hostname saigo
setup-apkrepos -1

printf "$INTERFACESOPTS" | setup-interfaces -i ${rst_if:+-r}

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

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
