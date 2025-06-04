#!/bin/bash

# --- CONFIGURATION ---
#DEVICE="hw:2,0"
DEVICE="dsnooper"
THRESHOLD_DB="-50"                      # dB threshold above which is considered "audio"
SILENCE_COUNT_LIMIT=3                  # how many consecutive silent readings before stopping
SAMPLE_DURATION=2                      # how long to sample (seconds)
STREAM_DEST="turntable2.local"
PORT="1234"
LOG_FILE="/var/log/audio_sender.log"

# --- STATE ---
IS_STREAMING=0
NC_PID=0
SILENCE_COUNT=0

echo "$(date): Starting audio silence monitor..." | tee -a "$LOG_FILE"

# --- Function to Measure Audio Level Reliably ---
get_db_level() {
  TMPFILE=$(mktemp)
  arecord -D "$DEVICE" -d "$SAMPLE_DURATION" -f S16_LE -r 44100 -c 2 -t raw "$TMPFILE" 2>/dev/null

  if [[ ! -s "$TMPFILE" ]]; then
    rm -f "$TMPFILE"
    echo "-999"  # No data captured
    return
  fi

  LEVEL=$(sox -t raw -r 44100 -b 16 -e signed -c 2 "$TMPFILE" -n stat 2>&1 \
    | awk '/RMS.*amplitude/ { print $3 }' \
    | xargs -I{} bash -c 'rms={}; if (( $(echo "$rms > 0" | bc -l) )); then echo "scale=2; 20*l($rms)/l(10)" | bc -l; else echo "-100"; fi')

  rm -f "$TMPFILE"
  echo "$LEVEL"
}

# --- Main Loop ---
while true; do
  LEVEL=$(get_db_level)

  if [[ "$LEVEL" == "-999" ]]; then
    echo "$(date): Warning: dropped bad sample (no data)" | tee -a "$LOG_FILE"
    sleep 1
    continue
  fi

  echo "$(date): Detected level = $LEVEL dB" | tee -a "$LOG_FILE"
  ACTIVE=$(echo "$LEVEL > $THRESHOLD_DB" | bc -l)

  if [[ "$ACTIVE" -eq 1 ]]; then
    SILENCE_COUNT=0
    if [[ "$IS_STREAMING" -eq 0 ]]; then
      echo "$(date): Audio active, starting stream to $STREAM_DEST:$PORT" | tee -a "$LOG_FILE"
      arecord -D "$DEVICE" -f cd -r 44100 -c 2 | nc "$STREAM_DEST" "$PORT" > /dev/null 2>&1 &
      NC_PID=$!
      IS_STREAMING=1
    fi
  elif [[ "$IS_STREAMING" -eq 1 ]]; then
    SILENCE_COUNT=$((SILENCE_COUNT + 1))
    echo "$(date): Silence count = $SILENCE_COUNT" | tee -a "$LOG_FILE"
    if [[ "$SILENCE_COUNT" -ge "$SILENCE_COUNT_LIMIT" ]]; then
      echo "$(date): Reached $SILENCE_COUNT_LIMIT consecutive silence readings — stopping stream" | tee -a "$LOG_FILE"
      kill "$NC_PID" 2>/dev/null
      wait "$NC_PID" 2>/dev/null
      IS_STREAMING=0
      SILENCE_COUNT=0
    fi
  fi

  sleep 2
done
