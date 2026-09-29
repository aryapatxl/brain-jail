#!/bin/bash
# ADHD Mode for macOS
# Usage: adhd-mode.sh [on|off|toggle] [minutes]   (default: toggle, 25 min)
#
# SETUP:
# 1. brew install dnsmasq && sudo brew services start dnsmasq
# 2. sudo mkdir -p /etc/resolver && echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/local
# 3. Add 127.0.0.1 to DNS in System Settings → Wi-Fi → your network → Details → DNS
# 4. echo "server=8.8.8.8" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf && sudo brew services restart dnsmasq
# 5. Chrome: turn off Settings → Privacy & Security → Use secure DNS

STATE="$HOME/.adhd-mode"
TIMER_PID="$HOME/.adhd-mode-timer.pid"
ANNOY_PID="$HOME/.adhd-mode-annoy.pid"
ANNOY_SCRIPT="$HOME/.adhd-mode-annoy.sh"
SERVER_PID="$HOME/.adhd-mode-server.pid"
START_TIME_FILE="$HOME/.adhd-mode-start"
BLOCK_PAGE="$HOME/bin/adhd-block-page"
DNSMASQ_CONF="/opt/homebrew/etc/dnsmasq.d/adhd-block.conf"
MINUTES="${2:-25}"

# ============================================================
# CUSTOMIZE BELOW
# ============================================================

# Apps to quit when ADHD mode turns on
APPS=("Slack" "Messages" "Discord" "Spotify" "Mail")

# Apps to keep killing every 0.5 seconds (the annoying ones)
ANNOY_APPS=("Messages" "WhatsApp")

# Sites to block (wildcards included — *.youtube.com is blocked too)
SITES=(
  youtube.com
  x.com
  twitter.com
  instagram.com
  reddit.com
  tiktok.com
  netflix.com
  facebook.com
  discord.com
)

# Minimum minutes before you can turn off ADHD mode
MIN_LOCK=20

# ============================================================
# DON'T TOUCH BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================

notify() {
  osascript -e "display alert \"ADHD Mode\" message \"$1\""
}

run_admin() {
  local f
  f=$(mktemp)
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
  if [ -f "$ANNOY_PID" ]; then
    kill "$(cat "$ANNOY_PID")" 2>/dev/null
    rm -f "$ANNOY_PID"
  fi
  rm -f "$ANNOY_SCRIPT"
}

start_server() {
  stop_server
  nohup python3 -m http.server 80 --directory "$BLOCK_PAGE" >/dev/null 2>&1 &
  echo $! > "$SERVER_PID"
}

stop_server() {
  if [ -f "$SERVER_PID" ]; then
    kill "$(cat "$SERVER_PID")" 2>/dev/null
    rm -f "$SERVER_PID"
  fi
}

block_sites() {
  {
    for s in "${SITES[@]}"; do
      echo "address=/$s/127.0.0.1"
    done
  } > "$DNSMASQ_CONF"
  run_admin "brew services restart dnsmasq"
}

unblock_sites() {
  echo "# ADHD block config - inactive" > "$DNSMASQ_CONF"
  run_admin "brew services restart dnsmasq"
}

start_timer() {
  stop_timer
  nohup bash -c "sleep $((MINUTES * 60)); osascript -e 'display alert \"ADHD Mode\" message \"Time is up. Take a break.\"'; say 'Break time'" >/dev/null 2>&1 &
  echo $! > "$TIMER_PID"
}

stop_timer() {
  if [ -f "$TIMER_PID" ]; then
    kill "$(cat "$TIMER_PID")" 2>/dev/null
    rm -f "$TIMER_PID"
  fi
}

check_lock() {
  if [ ! -f "$START_TIME_FILE" ]; then return 0; fi
  local start elapsed remaining
  start=$(cat "$START_TIME_FILE")
  elapsed=$(( $(date +%s) - start ))
  remaining=$(( (MIN_LOCK * 60) - elapsed ))
  if [ $remaining -gt 0 ]; then
    local mins=$(( remaining / 60 ))
    local secs=$(( remaining % 60 ))
    notify "Locked for ${mins}m ${secs}s more. Stay focused."
    exit 1
  fi
}

mode_on() {
  if [ -f "$STATE" ]; then
    notify "Already on"
    return
  fi
  quit_apps
  start_annoy
  start_server
  block_sites
  start_timer
  date +%s > "$START_TIME_FILE"
  touch "$STATE"
  notify "ON for $MINUTES min. Locked for ${MIN_LOCK} min. No escape. 🔒"
}

mode_off() {
  if [ ! -f "$STATE" ]; then
    notify "Already off"
    return
  fi
  check_lock
  stop_annoy
  stop_server
  unblock_sites
  stop_timer
  rm -f "$STATE" "$START_TIME_FILE"
  notify "OFF. Nice work."
}

case "${1:-toggle}" in
  on)     mode_on ;;
  off)    mode_off ;;
  toggle) if [ -f "$STATE" ]; then mode_off; else mode_on; fi ;;
  *)      echo "Usage: $0 [on|off|toggle] [minutes]" ;;
esac
