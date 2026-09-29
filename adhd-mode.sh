#!/bin/bash
# ADHD Mode for macOS — Full Pomodoro Edition
# Usage: adhd-mode.sh [on|off|toggle]

STATE="$HOME/.adhd-mode"
ANNOY_PID="$HOME/.adhd-mode-annoy.pid"
ANNOY_SCRIPT="$HOME/.adhd-mode-annoy.sh"
SERVER_PID="$HOME/.adhd-mode-server.pid"
START_TIME_FILE="$HOME/.adhd-mode-start"
POMO_PID="$HOME/.adhd-mode-pomo.pid"
POMO_SCRIPT="$HOME/.adhd-mode-pomo.sh"
BLOCK_PAGE="$HOME/bin/adhd-block-page"
DNSMASQ_CONF="/opt/homebrew/etc/dnsmasq.d/adhd-block.conf"

# ---- Customize these ----
APPS=("Slack" "Messages" "Discord" "Spotify" "Mail")
ANNOY_APPS=("Messages" "WhatsApp")
SITES=(youtube.com x.com twitter.com instagram.com reddit.com tiktok.com netflix.com facebook.com discord.com)
WORK_MINS=25
BREAK_MINS=5
LONG_BREAK_MINS=15
ROUNDS_BEFORE_LONG=4
MIN_LOCK=20
# -------------------------

notify() {
  osascript -e "display alert \"ADHD Mode\" message \"$1\""
}

run_admin() {
  local f; f=$(mktemp)
  echo "$1" > "$f"
  osascript -e "do shell script \"/bin/bash $f\" with administrator privileges"
  rm -f "$f"
}

quit_apps() {
  for app in "${APPS[@]}"; do
    osascript -e "if application \"$app\" is running then tell application \"$app\" to quit" 2>/dev/null
  done
}

start_annoy() {
  stop_annoy
  cat > "$ANNOY_SCRIPT" << 'ANNOY'
#!/bin/bash
while true; do
  for app in "Messages" "WhatsApp"; do
    osascript -e "if application \"$app\" is running then tell application \"$app\" to quit" 2>/dev/null
  done
  sleep 0.5
done
ANNOY
  chmod +x "$ANNOY_SCRIPT"
  nohup bash "$ANNOY_SCRIPT" >/dev/null 2>&1 &
  echo $! > "$ANNOY_PID"
}

stop_annoy() {
  [ -f "$ANNOY_PID" ] && kill "$(cat "$ANNOY_PID")" 2>/dev/null; rm -f "$ANNOY_PID" "$ANNOY_SCRIPT"
}

start_server() {
  stop_server
  nohup python3 -m http.server 80 --directory "$BLOCK_PAGE" >/dev/null 2>&1 &
  echo $! > "$SERVER_PID"
}

stop_server() {
  [ -f "$SERVER_PID" ] && kill "$(cat "$SERVER_PID")" 2>/dev/null; rm -f "$SERVER_PID"
}

block_sites() {
  { for s in "${SITES[@]}"; do echo "address=/$s/127.0.0.1"; done } > "$DNSMASQ_CONF"
  run_admin "brew services restart dnsmasq"
}

unblock_sites() {
  echo "# ADHD block config - inactive" > "$DNSMASQ_CONF"
  run_admin "brew services restart dnsmasq"
}

check_lock() {
  [ ! -f "$START_TIME_FILE" ] && return 0
  local start elapsed remaining
  start=$(cat "$START_TIME_FILE")
  elapsed=$(( $(date +%s) - start ))
  remaining=$(( (MIN_LOCK * 60) - elapsed ))
  if [ $remaining -gt 0 ]; then
    notify "Locked for $(( remaining / 60 ))m $(( remaining % 60 ))s more. Stay focused."
    exit 1
  fi
}

start_pomodoro() {
  stop_pomodoro
  cat > "$POMO_SCRIPT" << POMO
#!/bin/bash
WORK_MINS=$WORK_MINS
BREAK_MINS=$BREAK_MINS
LONG_BREAK_MINS=$LONG_BREAK_MINS
ROUNDS_BEFORE_LONG=$ROUNDS_BEFORE_LONG
DNSMASQ_CONF="$DNSMASQ_CONF"
SITES=(${SITES[@]})
BLOCK_PAGE="$BLOCK_PAGE"
SERVER_PID="$SERVER_PID"
STATE="$STATE"

block() {
  { for s in "\${SITES[@]}"; do echo "address=/\$s/127.0.0.1"; done } > "\$DNSMASQ_CONF"
  osascript -e 'do shell script "brew services restart dnsmasq" with administrator privileges'
  kill "\$(cat \$SERVER_PID)" 2>/dev/null
  python3 -m http.server 80 --directory "\$BLOCK_PAGE" >/dev/null 2>&1 &
  echo \$! > "\$SERVER_PID"
}

unblock() {
  echo "# inactive" > "\$DNSMASQ_CONF"
  osascript -e 'do shell script "brew services restart dnsmasq" with administrator privileges'
  kill "\$(cat \$SERVER_PID)" 2>/dev/null
  rm -f "\$SERVER_PID"
}

round=0
MAX_MINS=180
start_time=\$(date +%s)

while [ -f "\$STATE" ]; do
  elapsed_mins=\$(( ( \$(date +%s) - start_time ) / 60 ))
  if [ \$elapsed_mins -ge \$MAX_MINS ]; then
    osascript -e "display alert \"ADHD Mode\" message \"3 hours done. Seriously, take a real break. 🛑\""
    say "Session complete"
    rm -f "\$STATE"
    break
  fi
  round=\$((round + 1))
  osascript -e "display alert \"ADHD Mode\" message \"Round \$round starting. Focus for \${WORK_MINS} min. 🔒\""
  say "Focus session starting"
  block
  sleep \$((WORK_MINS * 60))
  [ ! -f "\$STATE" ] && break

  if [ \$((round % ROUNDS_BEFORE_LONG)) -eq 0 ]; then
    BMIN=\$LONG_BREAK_MINS
    MSG="Long break — \${LONG_BREAK_MINS} min. You earned it. 🎉"
  else
    BMIN=\$BREAK_MINS
    MSG="Break time — \${BREAK_MINS} min. Step away. ☕"
  fi

  osascript -e "display alert \"ADHD Mode\" message \"\$MSG\""
  say "Break time"
  afplay /System/Library/Sounds/Glass.aiff
  unblock
  sleep \$((BMIN * 60))
done
POMO
  chmod +x "$POMO_SCRIPT"
  nohup bash "$POMO_SCRIPT" >/dev/null 2>&1 &
  echo $! > "$POMO_PID"
}

stop_pomodoro() {
  [ -f "$POMO_PID" ] && kill "$(cat "$POMO_PID")" 2>/dev/null; rm -f "$POMO_PID" "$POMO_SCRIPT"
}

mode_on() {
  [ -f "$STATE" ] && { notify "Already on"; return; }
  quit_apps
  start_annoy
  start_server
  block_sites
  date +%s > "$START_TIME_FILE"
  touch "$STATE"
  start_pomodoro
  notify "Pomodoro started. ${WORK_MINS}/${BREAK_MINS} min, long break every ${ROUNDS_BEFORE_LONG} rounds. Locked for ${MIN_LOCK} min. 🔒"
}

mode_off() {
  [ ! -f "$STATE" ] && { notify "Already off"; return; }
  check_lock
  stop_annoy
  stop_server
  stop_pomodoro
  unblock_sites
  rm -f "$STATE" "$START_TIME_FILE"
  notify "OFF. Nice work."
}

case "${1:-toggle}" in
  on)     mode_on ;;
  off)    mode_off ;;
  toggle) [ -f "$STATE" ] && mode_off || mode_on ;;
  *)      echo "Usage: $0 [on|off|toggle]" ;;
esac
