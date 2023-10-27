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
mkdir -p "$tmp"/etc/init.d

cp ~/aports/scripts/wallpaper.png "$tmp"/etc/wallpaper.png

makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
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
xf86-input-vmmouse
xf86-input-synaptics
xf86-input-evdev
feh
tint2
EOF

makefile root:root 0755 "$tmp"/etc/xinitrc <<EOF
feh --bg-fill /etc/wallpaper.png &
tint2 &
exec openbox-session
EOF

makefile root:root 0755 "$tmp"/etc/setup.sh <<EOF
#!/bin/sh -e

mv /etc/.xinitrc /root/.xinitrc
startx
EOF

makefile root:root 0755 "$tmp"/etc/init.d/setup <<EOF
#!/sbin/openrc-run

command="/etc/setup.sh"
command_args=""
command_background="yes"
start_stop_daemon_args="--background --start --exec"

depend() {
	need localmount
}
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
rc_add setup boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
