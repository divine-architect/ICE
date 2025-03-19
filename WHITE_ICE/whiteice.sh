#!/bin/bash

echo "Starting system hardening process..."

echo "Removing openssh-server"
sudo apt remove --purge openssh-server -y

if ! dpkg -l | grep -q openssh-server; then
    echo "[✅] OpenSSH Server successfully removed!"
else
    echo "[❌] Failed to remove OpenSSH Server!"
    exit 1
fi

echo "Setting up firewall"
sudo apt install ufw -y

sudo ufw default allow outgoing && \
sudo ufw default deny incoming && \
sudo ufw logging on && \
sudo ufw enable
sudo ufw status verbose

if sudo ufw status | grep -q "Status: active"; then
  echo "[✅] Firewall is active"
else
  echo "[❌] Firewall is not active"
fi

echo "Setting up Fail2Ban"
sudo apt install fail2ban -y

if ! dpkg -l | grep -q fail2ban; then
    echo "[❌] Failed to install Fail2Ban!"
    exit 1
fi

sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

sudo tee /etc/fail2ban/jail.d/custom.conf > /dev/null << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

if sudo systemctl is-active fail2ban > /dev/null; then
    echo "[✅] Fail2Ban is active and running"
else
    echo "[❌] Fail2Ban failed to start"
    exit 1
fi

echo "Setting up ClamAV antivirus"
sudo apt install clamav clamav-daemon -y

if ! dpkg -l | grep -q clamav; then
    echo "[❌] Failed to install ClamAV!"
    exit 1
fi

echo "Updating ClamAV virus definitions"
sudo systemctl stop clamav-freshclam
sudo freshclam

sudo mkdir -p /etc/clamav/custom
sudo tee /etc/clamav/custom/scan.sh > /dev/null << 'EOF'
#!/bin/bash
LOGFILE="/var/log/clamav/custom_scan.log"
echo "$(date): Starting scan" >> $LOGFILE
clamscan -r --infected /home >> $LOGFILE
echo "$(date): Scan complete" >> $LOGFILE
EOF

sudo chmod +x /etc/clamav/custom/scan.sh

(crontab -l 2>/dev/null || echo "") | grep -v "/etc/clamav/custom/scan.sh" | { cat; echo "0 3 * * 0 /etc/clamav/custom/scan.sh"; } | crontab -

sudo systemctl enable clamav-daemon
sudo systemctl restart clamav-daemon

if sudo systemctl is-active clamav-daemon > /dev/null; then
    echo "[✅] ClamAV is active and running"
else
    echo "[❌] ClamAV daemon failed to start"
    exit 1
fi

echo "Setting up AIDE (Advanced Intrusion Detection Environment)"
sudo apt install aide -y

if ! dpkg -l | grep -q aide; then
    echo "[❌] Failed to install AIDE!"
    exit 1
fi

echo "Initializing AIDE database (this may take some time)"
# wrapper init
sudo aideinit

#database movement
if [ -f "/var/lib/aide/aide.db.new" ]; then
    sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    echo "[✅] AIDE database initialized"
else
    echo "[❌] AIDE database initialization failed"
fi

sudo mkdir -p /var/log/aide

sudo tee /etc/cron.daily/aide-check > /dev/null << 'EOF'
#!/bin/bash
LOGFILE="/var/log/aide/aide-check.log"
MAILADDR="root"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo "$DATE: Running AIDE check" >> $LOGFILE
#wrapper because aide was being weird
/usr/bin/aide.wrapper --check >> $LOGFILE 2>&1
RESULT=$?

if [ $RESULT -ne 0 ]; then
    echo "AIDE detected file changes on $(hostname) at $DATE" | mail -s "AIDE Alert: $(hostname)" $MAILADDR
    echo "$DATE: AIDE detected changes (exit code $RESULT)" >> $LOGFILE
else
    echo "$DATE: No changes detected" >> $LOGFILE
fi
EOF

sudo chmod +x /etc/cron.daily/aide-check

echo "[✅] AIDE setup complete"

echo "[✅] AIDE setup complete"

echo "Setting up kernel hardening via sysctl"
sudo tee /etc/sysctl.d/99-hardening.conf > /dev/null << EOF
#spoof 
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1


net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5


net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# icmp redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0


net.ipv4.icmp_echo_ignore_broadcasts = 1


net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0


net.ipv4.ip_forward = 0


net.ipv4.tcp_timestamps = 0


kernel.randomize_va_space = 2

# pointer leak
kernel.kptr_restrict = 1


kernel.yama.ptrace_scope = 1

# Restrict dmesg access
kernel.dmesg_restrict = 1


net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
EOF

sudo sysctl -p /etc/sysctl.d/99-hardening.conf

echo "[✅] Kernel hardening complete"

echo "System hardening complete!"
