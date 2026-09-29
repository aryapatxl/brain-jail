# adhd-mode 🔒

a mac script that blocks sites, kills messaging apps, and locks you in for 20 minutes min. built to start focus

## what it does

- kills Slack, Messages, Discord, Spotify, Mail on startup
- keeps killing Messages + WhatsApp every 0.5 seconds (yes really)
- blocks distracting sites at the DNS level — wildcards included, so no sneaky subdomains
- redirects blocked sites to a "get back to work" page instead of just erroring
- starts a 25 min focus timer
- won't let you turn it off for the first 20 minutes

## requirements

- macOS
- [Homebrew](https://brew.sh)
- dnsmasq (`brew install dnsmasq`)
- Python 3 (comes with macOS)

## setup

```bash
# 1. clone the repo
git clone https://github.com/yourname/adhd-mode.git
cd adhd-mode

# 2. put the script somewhere on your PATH
mkdir -p ~/bin
cp adhd-mode.sh ~/bin/adhd-mode.sh
chmod +x ~/bin/adhd-mode.sh

# 3. install and start dnsmasq
brew install dnsmasq
sudo brew services start dnsmasq

# 4. point your DNS to localhost
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/local

# 5. add 127.0.0.1 to your DNS servers
# System Settings → Wi-Fi → your network → Details → DNS → add 127.0.0.1

# 6. set up the block page
mkdir -p ~/bin/adhd-block-page
cp index.html ~/bin/adhd-block-page/
```

## usage

```bash
# turn on (25 min session, 20 min lock)
bash ~/bin/adhd-mode.sh on

# turn off (only works after 20 min)
bash ~/bin/adhd-mode.sh off

# toggle
bash ~/bin/adhd-mode.sh toggle

# custom session length
bash ~/bin/adhd-mode.sh on 50
```

## customize

at the top of `adhd-mode.sh`:

```bash
APPS=("Slack" "Messages" "Discord" "Spotify" "Mail")   # apps to quit on start
ANNOY_APPS=("Messages" "WhatsApp")                      # apps to keep killing
SITES=(youtube.com reddit.com ...)                      # sites to block
MIN_LOCK=20                                             # minutes before you can turn off
```

## notes

- Chrome users: turn off secure DNS or it'll ignore the blocking. Settings → Privacy & Security → Use secure DNS → off
- the lock is enforced in the script, not at the OS level. if you're the type to just delete the state file... maybe therapy
- dnsmasq wildcards mean `*.youtube.com` is blocked too, not just the homepage
