#!/bin/bash

set -e

function NewPassword {
  # Add slash so people don't IRC the password ;)
  echo "/$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)"
}

function Color {
  echo -en '\E[40;0;31m'
  echo "$@"
  tput sgr0
}

yes | apt-get update
yes | apt-get upgrade
PWD="$(NewPassword)"
Color "Setting root password to: $PWD"
passwd << EOF
$PWD
$PWD
EOF

yes | apt-get install fail2ban

Color -n "Enter username for non-root user: "
read USERNAME

useradd -m $USERNAME
PWD="$(NewPassword)"
Color "Setting $USERNAME password to: $PWD"
passwd $USERNAME << EOF
$PWD
$PWD
EOF

echo "Editing Sudoers file"
cat > /etc/sudoers << EOF
root      ALL=(ALL) ALL
$USERNAME ALL=(ALL) ALL
EOF

mkdir -p /home/$USERNAME/.ssh
chown 700 /home/$USERNAME/.ssh
Color "Enter authorized_keys for remote SSH by $USERNAME:"
cat > /home/$USERNAME/.ssh/authorized_keys
chmod 400 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME

Color -n "TEST REMOTE SSH, TYPE 'YES' TO CONTINUE: "
read YN
if [ "$YN" != "YES" ]; then
  echo "Stopping"
  exit 1
fi

echo "Locking down SSH"
sed -i 's/^PermitRootLogin .*$//' /etc/ssh/sshd_config
cat >> /etc/ssh/sshd_config << EOF
PermitRootLogin no
EOF
service ssh restart

echo "Setting up firewall"
yes | apt-get install ufw
ufw allow 22
yes | ufw enable

yes | apt-get install update-notifier-common
yes | apt-get install unattended-upgrades
cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

Color "Check /etc/apt/apt.conf.d/50unattended-upgrades to make sure that "
Color "Allowed-Origins includes distro-security"
