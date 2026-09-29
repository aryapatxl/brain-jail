# adhd-mode 🔒
 
a mac script that locks you into a full pomodoro session and makes it actually hard to get distracted. blocks sites, kills messaging apps, and won't let you quit for 20 minutes min
 
## what it does
 
- kills apps on startup
- lets you block specified apps from opening
- blocks distracting sites at the DNS level — wildcards included, so no sneaky subdomains
- redirects blocked sites to a "get back to work" page
- runs a full pomodoro loop: 25 min focus → 5 min break → repeat, with a 15 min long break every 4 rounds
- won't let you turn it off for the first 20 minutes
- auto-kills itself after 3 hours so you don't forget
## pomodoro flow
 
```
round 1: 25 min focus 🔒 → 5 min break ☕
round 2: 25 min focus 🔒 → 5 min break ☕
round 3: 25 min focus 🔒 → 5 min break ☕
round 4: 25 min focus 🔒 → 15 min long break 🎉
repeat until 3 hours or you turn it off
```
 
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
 
# 4. forward DNS upstream
echo "server=8.8.8.8" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf
sudo brew services restart dnsmasq
 
# 5. point your DNS to localhost
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/local
 
# 6. add 127.0.0.1 to your DNS servers
# System Settings → Wi-Fi → your network → Details → DNS → add 127.0.0.1
 
# 7. set up the block page
mkdir -p ~/bin/adhd-block-page
cp index.html ~/bin/adhd-block-page/
```
 
## usage
 
```bash
# turn on
bash ~/bin/adhd-mode.sh on
 
# turn off (only works after 20 min)
bash ~/bin/adhd-mode.sh off
 
# toggle
bash ~/bin/adhd-mode.sh toggle
```
 
## customize
 
at the top of `adhd-mode.sh`:
 
```bash
APPS=("Slack" "Messages" "Discord" "Spotify" "Mail")  # apps to quit on start
ANNOY_APPS=("Messages" "WhatsApp")                     # apps to keep killing every 0.5s
SITES=(youtube.com reddit.com ...)                     # sites to block
WORK_MINS=25                                           # focus session length
BREAK_MINS=5                                           # short break length
LONG_BREAK_MINS=15                                     # long break length
ROUNDS_BEFORE_LONG=4                                   # rounds before long break
MIN_LOCK=20                                            # minutes before you can turn off
```
 
## notes
 
- Chrome users: turn off secure DNS or it'll ignore the blocking — Settings → Privacy & Security → Use secure DNS → off
- the 20 min lock is enforced in the script, not at the OS level. if you're the type to just delete the state file... maybe therapy
- dnsmasq wildcards mean `*.youtube.com` is blocked too, not just the homepage
- after 3 hours it kills itself and tells you to go outside
## why
 
wanted to create a more practical pomodoro function
