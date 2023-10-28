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
xf86-video-intel
xf86-input-vmmouse
xf86-input-synaptics
xf86-input-evdev
feh
tint2
firefox
alsa-utils
alsaconf
pulseaudio
pulseaudio-utils
pavucontrol-qt
agetty
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
tint2 &
exec openbox-session
EOF

makefile root:root 0755 "$tmp"/etc/.profile <<EOF
#!/bin/sh -e

setup-devd udev
startx
EOF

makefile root:root 0755 "$tmp"/etc/setup.sh <<EOF
mkdir -p /root/.config
tar -xzvf /etc/tint2.tar.gz -C /root/.config
tar -xzvf /etc/openbox.tar.gz -C /root/.config

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
