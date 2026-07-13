#!/usr/bin/env bash
set -euo pipefail

image="${1:-ledfxdocker:smoke}"
container="ledfxdocker-smoke-${GITHUB_RUN_ID:-$$}"

cleanup() {
    docker rm --force "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

restart_count() {
    docker inspect --format '{{.RestartCount}}' "$container"
}

wait_for_restart() {
    local previous_count=$1

    for _ in {1..60}; do
        if [[ "$(restart_count)" -gt "$previous_count" ]]; then
            return 0
        fi
        sleep 1
    done

    echo "Container did not restart after a critical process exited." >&2
    docker logs "$container" >&2
    return 1
}

wait_for_services() {
    for _ in {1..90}; do
        if docker exec "$container" bash -c \
            "ps -eo stat=,comm= | awk '\$2 == \"snapclient\" && \$1 !~ /^Z/ { found=1 } END { exit !found }'" \
            && docker exec "$container" python -c \
            "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8888', timeout=2)" \
            >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "LedFx and Snapclient did not become ready." >&2
    docker logs "$container" >&2
    return 1
}

kill_snapclient() {
    docker exec "$container" bash -c \
        "pid=\$(ps -eo pid=,stat=,comm= | awk '\$3 == \"snapclient\" && \$2 !~ /^Z/ { print \$1; exit }'); test -n \"\$pid\"; kill \"\$pid\""
}

kill_ledfx() {
    docker exec "$container" bash -c \
        "pid=\$(ps -eo pid=,args= | awk '\$0 ~ /[l]edfx.*-c \/app\/ledfx-config/ { print \$1; exit }'); test -n \"\$pid\"; kill \"\$pid\""
}

docker run --detach \
    --name "$container" \
    --restart unless-stopped \
    --env HOST=127.0.0.1 \
    "$image" >/dev/null

wait_for_services
# Docker only activates a restart policy after a container has remained up long
# enough to be considered successfully started.
sleep 10

before_restart=$(restart_count)
kill_snapclient
wait_for_restart "$before_restart"
wait_for_services
sleep 10

before_restart=$(restart_count)
kill_ledfx
wait_for_restart "$before_restart"
wait_for_services

before_stop=$(restart_count)
docker stop --time 15 "$container" >/dev/null
sleep 3

if [[ "$(docker inspect --format '{{.State.Running}}' "$container")" != "false" ]]; then
    echo "Container restarted after an intentional stop." >&2
    exit 1
fi

if [[ "$(restart_count)" -ne "$before_stop" ]]; then
    echo "Restart count changed after an intentional stop." >&2
    exit 1
fi

echo "Smoke test passed: both critical process failures restarted the container."
