#!/bin/bash
set -e

export VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/venv}"
export PATH="$VIRTUAL_ENV/bin:$PATH"

# Start avahi daemon for WLED auto discovery
avahi-daemon --daemonize --no-drop-root

# https://superuser.com/questions/1539634/pulseaudio-daemon-wont-start-inside-docker
# Start the pulseaudio server
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse
pulseaudio -D --verbose --exit-idle-time=-1 --system --disallow-exit

if [[ -n "${FORMAT+x}" ]]; then
    ./pipe-audio.sh
fi

if [[ -n "${HOST+x}" ]]; then
    snapclient --host "$HOST" --daemon 1
fi

if [[ -n "${SQUEEZE+x}" ]]; then
    ./squeeze.sh
fi

mkdir -p /app/ledfx-config /root/.ledfx

if [[ -f /app/config.yaml && ! -f /app/ledfx-config/config.yaml ]]; then
    cp -v /app/config.yaml /app/ledfx-config/config.yaml
fi

exec "$VIRTUAL_ENV/bin/ledfx" -c /app/ledfx-config
