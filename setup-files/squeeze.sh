#!/bin/bash

if [ "$SQUEEZE" == "1" ]; then
    mkdir -p /app/ledfx-config
    if [[ -f /app/squeeze.conf ]]; then
        cp -vn /app/squeeze.conf /app/ledfx-config/
    fi
    cp -v /app/ledfx-config/squeeze.conf /etc/default/squeezelite
    /etc/init.d/squeezelite start
fi
