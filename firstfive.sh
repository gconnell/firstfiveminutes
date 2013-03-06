#!/bin/bash

set -e

function NewPassword {
  # Add slash so people don't IRC the password ;)
  echo "/$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)"
}

yes | apt-get update
yes | apt-get upgrade
PWD="$(NewPassword)"
echo "Setting root password to: $PWD"
passwd << EOF
$PWD
$PWD
EOF

yes | apt-get install fail2ban

echo -n "Enter username for non-root user: "
read USERNAME

useradd -m $USERNAME
PWD="$(NewPassword)"
echo "Setting $USERNAME password to: $PWD"
passwd $USERNAME << EOF
$PWD
$PWD
EOF

echo "Editing Sudoers file"
cat > /etc/sudoers << EOF
root      ALL=(ALL) ALL
$USERNAME ALL=(ALL) ALL
EOF

mkdir ~$USERNAME/.ssh
chown 700 ~$USERNAME/.ssh
echo "Enter authorized_keys for remote SSH by $USERNAME:"
cat > ~$USERNAME/.ssh/authorized_keys
chmod 400 ~$USERNAME/.ssh/authorized_keys
chown $USERNAME:$USERNAME ~$USERNAME

echo -n "TEST REMOTE SSH, TYPE 'YES' TO CONTINUE: "
read YN
if [ "$YN" != "YES" ]; then
  echo "Stopping"
  exit 1
fi

echo "Locking down SSH"
sed -i 's/^PermitRootLogin .*$//' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication .*//' /etc/ssh/sshd_config
cat >> /etc/ssh/sshd_config << EOF
PermitRootLogin no
PasswordAuthentication no
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

echo "Check /etc/apt/apt.conf.d/50unattended-upgrades to make sure that "
echo "Allowed-Origins includes distro-security"
