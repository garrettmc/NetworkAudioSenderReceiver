#!/bin/bash

PORT="1234"
AUDIO_DEVICE="hw:2,0"
LOG_FILE="/var/log/audio_receiver.log"

MBUFFER_SIZE="1M"
MBUFFER_PREFILL_KB="1"  # Only ~5ms delay

while true; do
  echo "$(date): Listening on port $PORT..." | tee -a "$LOG_FILE"

  nc -l -p "$PORT" \
    | mbuffer -q -m "$MBUFFER_SIZE" -P "$MBUFFER_PREFILL_KB" \
    | aplay -D "$AUDIO_DEVICE" -t raw -f S16_LE -r 44100 -c 2 2>> "$LOG_FILE"

  echo "$(date): Stream ended" | tee -a "$LOG_FILE"
  sleep 1
done

