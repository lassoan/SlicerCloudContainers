#!/bin/bash
until xdpyinfo -display :1 >/dev/null 2>&1; do sleep 1; done

export DISPLAY=:1
export HOME=/home/desktop
export USER=desktop
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/user/$(id -u desktop)
export QT_QPA_PLATFORM=xcb

if command -v vglrun >/dev/null 2>&1; then
	exec dbus-run-session -- bash -c 'openbox & sleep 2 && xset r on && xset r rate 500 25 && autocutsel -fork && autocutsel -selection PRIMARY -fork && vglrun -d egl plasmashell'
fi

exec dbus-run-session -- bash -c 'openbox & sleep 2 && xset r on && xset r rate 500 25 && autocutsel -fork && autocutsel -selection PRIMARY -fork && plasmashell'
