#!/bin/bash
set -e

export VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/venv}"
export PATH="$VIRTUAL_ENV/bin:$PATH"

# Start avahi daemon for WLED auto discovery
mkdir -p /run/avahi-daemon
rm -f /run/avahi-daemon/pid
chown avahi:avahi /run/avahi-daemon || true
if ! avahi-daemon --daemonize --no-drop-root; then
    echo "Warning: avahi-daemon failed to start; WLED auto discovery may not work." >&2
fi

# https://superuser.com/questions/1539634/pulseaudio-daemon-wont-start-inside-docker
# Start the pulseaudio server
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse
if ! pulseaudio -D --exit-idle-time=-1 --system --disallow-exit --disallow-module-loading; then
    echo "Warning: pulseaudio failed to start; audio input may not work." >&2
fi

if [[ -n "${FORMAT+x}" ]]; then
    if ! ./pipe-audio.sh; then
        echo "Warning: named pipe audio failed to start." >&2
    fi
fi

if [[ -n "${HOST+x}" ]]; then
    if ! snapclient --host "$HOST" --daemon 1; then
        echo "Warning: snapclient failed to start for host '$HOST'." >&2
    fi
fi

if [[ -n "${SQUEEZE+x}" ]]; then
    if ! ./squeeze.sh; then
        echo "Warning: squeezelite failed to start." >&2
    fi
fi

mkdir -p /app/ledfx-config /root/.ledfx

if [[ -f /app/config.yaml && ! -f /app/ledfx-config/config.yaml ]]; then
    cp -v /app/config.yaml /app/ledfx-config/config.yaml
fi

if [[ ! -x "$VIRTUAL_ENV/bin/ledfx" ]]; then
    echo "Error: LedFx executable not found at $VIRTUAL_ENV/bin/ledfx." >&2
    ls -la "$VIRTUAL_ENV/bin" >&2 || true
    exit 1
fi

echo "Starting LedFx..."
exec "$VIRTUAL_ENV/bin/ledfx" -c /app/ledfx-config
