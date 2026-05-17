#!/bin/bash

mkdir -p /app/audio
rm -f /app/audio/stream
mkfifo -m a+rw /app/audio/stream
while true; do cat /app/audio/stream | aplay $FORMAT; done &
