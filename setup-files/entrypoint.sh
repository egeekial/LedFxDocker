#!/bin/bash
set -e

export VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/venv}"
export PATH="$VIRTUAL_ENV/bin:$PATH"
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"
PULSE_SINK="${PULSE_SINK:-ledfx_snapcast}"
PULSE_SOURCE="${PULSE_SOURCE:-$PULSE_SINK.monitor}"

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
if ! pulseaudio -D --exit-idle-time=-1 --system --disallow-exit --disallow-module-loading \
    -L "module-null-sink sink_name=$PULSE_SINK sink_properties=device.description=LedFxSnapcast"; then
    echo "Warning: pulseaudio failed to start; audio input may not work." >&2
fi

for _ in {1..20}; do
    [[ -S /run/pulse/native ]] && break
    sleep 0.1
done

if command -v pactl >/dev/null 2>&1; then
    pactl set-default-sink "$PULSE_SINK" || echo "Warning: could not set PulseAudio default sink to '$PULSE_SINK'." >&2
    pactl set-default-source "$PULSE_SOURCE" || echo "Warning: could not set PulseAudio default source to '$PULSE_SOURCE'." >&2
fi

if [[ -n "${FORMAT+x}" ]]; then
    if ! ./pipe-audio.sh; then
        echo "Warning: named pipe audio failed to start." >&2
    fi
fi

if [[ -n "${HOST+x}" ]]; then
    SNAPCLIENT_PLAYER="${SNAPCLIENT_PLAYER:-pulse:server=$PULSE_SERVER}"
    snapclient_args=(--host "$HOST" --player "$SNAPCLIENT_PLAYER")
    if [[ -n "${SNAPCLIENT_OPTS:-}" ]]; then
        read -r -a snapclient_extra_args <<< "$SNAPCLIENT_OPTS"
        snapclient_args+=("${snapclient_extra_args[@]}")
    fi

    echo "Starting Snapclient for '$HOST' with player '$SNAPCLIENT_PLAYER'..."
    snapclient "${snapclient_args[@]}" &
    snapclient_pid=$!
    sleep 1
    if ! kill -0 "$snapclient_pid" 2>/dev/null; then
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
