# LedFxDocker

A Docker image for [LedFx](https://github.com/LedFx/LedFx.git), based on Debian 13 `trixie`.

This fork publishes the supported image to GitHub Container Registry:

```sh
docker pull ghcr.io/egeekial/ledfxdocker:latest
```

The image includes LedFx, PulseAudio, Snapcast client support, named-pipe audio support, WLED discovery support through Avahi, and optional Logitech Media Server support through `squeezelite`.

## Supported Architectures

The published image is built for:

| Platform | Notes |
| --- | --- |
| `linux/amd64` | x86-64 systems |
| `linux/arm64` | 64-bit ARM systems |
| `linux/arm/v7` | 32-bit ARMv7 systems |

Docker automatically pulls the matching platform when one is available.

## Setup

Use the published GHCR image for normal installs:

```yaml
services:
  ledfx:
    image: ghcr.io/egeekial/ledfxdocker:latest
    container_name: ledfx
    environment:
      - HOST=host.docker.internal
    ports:
      - 8888:8888
    volumes:
      - ~/ledfx-config:/app/ledfx-config
      - ~/audio:/app/audio
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Only set the audio input variables you need. For example, remove `SQUEEZE` if you are not using Logitech Media Server, remove `HOST` if you are not connecting to a Snapcast server, and remove `FORMAT` if you are not writing audio to `/app/audio/stream`.

Network discovery works best with host networking:

```yaml
network_mode: host
```

Host networking can behave differently on Docker Desktop for macOS and Windows, so keep bridge networking if portability matters more than discovery.

## Volumes

| Volume | Function |
| --- | --- |
| `/app/ledfx-config` | LedFx configuration files. A named volume works if you do not need to edit files directly. |
| `/app/audio` | Contains a named pipe called `stream` when `FORMAT` is set. Write raw audio data here from FFmpeg, Mopidy, PulseAudio, or another source. |

## Environment Variables

At least one audio input should be configured.

| Variable | Function |
| --- | --- |
| `HOST` | Snapcast server hostname or IP, resolved from inside the container. Use an IP address or `network_mode: host` if local hostnames do not resolve from inside Docker. |
| `SNAPCLIENT_PLAYER` | Optional Snapclient player override. Defaults to `pulse:server=unix:/run/pulse/native`. |
| `SNAPCLIENT_OPTS` | Optional extra Snapclient arguments. |
| `FORMAT` | Audio format passed to `aplay` for `/app/audio/stream`, such as `-r 44100 -f S16_LE -c 2`. |
| `SQUEEZE` | Set to `1` to start `squeezelite` for Logitech Media Server. |

## Sending Audio

### Snapcast

[Snapcast](https://github.com/badaix/snapcast) is a server for synchronous multi-room audio. Set `HOST` to make this image act as a Snapcast client.

Snapclient writes the stream into the container's PulseAudio server by default. In the LedFx UI, open audio settings and select the `pulse` audio input. If reactive effects still do not move, verify that the container logs show `Starting Snapclient` without a failure warning, then try setting `HOST` to the Snapcast server IP address instead of a local DNS name.

### Named Pipe

Set `FORMAT` to create `/app/audio/stream`, then write raw audio to that pipe. Any Snapcast named-pipe audio guide is generally applicable. The [Snapcast player setup documentation](https://github.com/badaix/snapcast/blob/master/doc/player_setup.md) includes examples for Mopidy, FFmpeg, PulseAudio, AirPlay, Spotify, VLC, and other sources.

### Logitech Media Server

Set `SQUEEZE=1` to run this image as a [squeezelite](https://github.com/ralph-irving/squeezelite) client for [Logitech Media Server](https://mysqueezebox.com/download). If discovery does not work across your network, edit `setup-files/squeeze.conf` and build a local image.

## Building Locally

To build this fork locally:

```sh
git clone https://github.com/egeekial/LedFxDocker.git
cd LedFxDocker
docker build -t ledfx:latest .
```

The included `docker-compose.yml` builds the local Dockerfile and tags it as `ledfx:latest`:

```sh
docker compose up --build
```

If your Docker install still uses the legacy compose binary, run:

```sh
docker-compose up --build
```

GitHub Actions publishes the multi-architecture GHCR image from `master` pushes.

## Support Commands

```sh
docker exec -it ledfx /bin/bash
docker logs ledfx
```

After the first GHCR publish, verify the package visibility in GitHub Packages if anonymous pulls should work.
