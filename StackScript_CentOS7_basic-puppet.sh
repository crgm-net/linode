#!/bin/bash

# <UDF name="USERA" default="user" Label="User name:" />
# <UDF name="PASSA" Label="User pass:" />
# <UDF name="KEY1" default="" Label="User SSH key 1:" />
# <UDF name="INSTPUPPET"  Label="Install Puppet" example="Add puppet labs repo. Install as standalone deployment." oneOf="NO,YES" default="YES" />

#
# Very basic CentOS 7 host setup with optional Puppet (standalone install)
#
# * Add a user with sudo, setup ssh keys
# * Update + install useful packages, epel
# * Firewalld for ssh only, running denyhosts
# * install puppet and run simple site.pp on host (configures cron job to run every 35m)
# * produces ~/.ssh/config and ~/.ssh/known_hosts for your client
#
# Reboots when complete
#

set -e
set -o verbose
thedate=$(date)
echo "Running CentOS 7 Stackscript - $thedate" | logger
mkdir -v /root/setupfiles/

exec > >(tee /root/stackscript.log)
exec 2>&1

######################################################################################################
# detect environment.

vmenc=$(dmesg | grep -i "Detected virtualization")

# VirtualBox
#echo "$vmenc" | grep -q "$oracle"
#if [ $? -eq 0 ];then
#  echo "[*] Virtualbox found"
#
#  # find script name, populate varibles from Linode StackScript UDF tags
#  echo "runs from ${BASH_SOURCE[0]}"
#  for NAME in `grep UDF ${BASH_SOURCE[0]}`; do
#      echo "$NAME"
#  done
#fi

######################################################################################################
# Firewall - nothing in

if [ ! -f /tmp/stackscript_fw ]; then
  touch /tmp/stackscript_fw
  systemctl start firewalld.service
  firewall-cmd --reload
  echo "[*] Firewalled"
fi

######################################################################################################
# Upgrade and install useful Packages

if [ ! -f /tmp/stackscript_yum ]; then
  touch /tmp/stackscript_yum

  yum -y update
  yum -y install epel-release
  yes | yum -y upgrade
  yes | yum -y install sudo denyhosts which lsof man mlocate tmux screen byobu htop vim lynx telnet nano wget curl git rsync zip bind-utils openssl-devel perl tcpdump ccze whois net-tools

  sleep 5s

  ### Install Puppet + Base manifest if set ###
  yumfin=$(pgrep yum | wc -l)
  if [ $yumfin -eq 0 ] && [ "$INSTPUPPET" == "YES" ]; then
    wget http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
    rpm -ivh puppetlabs-release-el-7.noarch.rpm
    yum -y update
    yes | yum -y upgrade
    yes | yum -y install puppet
    # puppet does not seem to like Transient hostnames
    hostnamectl set-hostname `hostname`
    mkdir -p /etc/puppet/{manifests,modules}
    touch /etc/puppet/manifests/site.pp

# create a simple site.pp to check system services are running
cat <<EOT >/etc/puppet/manifests/site.pp
### CentOS 7 Minimal install - check base ###

cron { puppetagentrun:
      command => "/usr/bin/puppet apply /etc/puppet/manifests/site.pp --logdest /var/log/puppet/agent_autorun.log",
      user    => root,
      minute  => '*/35',
}

package { 'openssh-server':
  ensure => latest,
} ->
file { '/etc/ssh/sshd_config':
  ensure => file,
  mode   => '0600',
} ~>
service { 'sshd':
  ensure => running,
  enable => true,
}
service { 'firewalld':
  ensure => running,
  enable => true,
}
service { "crond":
    enable => true,
    ensure => "running",
}
service { "rsyslog":
    enable => true,
    ensure => "running",
}
service { "auditd":
    enable => true,
    ensure => "running",
}

file { '/root/puppet_file.txt':
    ensure => "file",
    owner  => "root",
    group  => "root",
    mode   => "600",
    content => "Puppet default site manifest run.",
}
EOT
    echo "alias puppetappysite='/usr/bin/puppet apply /etc/puppet/manifests/site.pp --logdest /var/log/puppet/agent_au
torun.log'" >> ~/.bashrc
    echo "[*] Puppet installed"
  fi

  echo "[*] Packages updated"
fi

######################################################################################################
# SSHD fixing: only allow $USERA to login via key. Get sshd fingerprints.

if [ ! -f /tmp/stackscript_ssh ]; then
  touch /tmp/stackscript_ssh

  # Security settings
  sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/#PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  sed -i 's/#LoginGraceTime 2m/LoginGraceTime 1m/' /etc/ssh/sshd_config
  sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
  sed -i 's/#StrictModes yes/StrictModes yes/' /etc/ssh/sshd_config
  sed -i 's/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config

  # use AllowUsers to limit ssh logins
  echo "AllowUsers $USERA" >> /etc/ssh/sshd_config
  echo "DenyGroups root" >> /etc/ssh/sshd_config

  # Gather SSHD info for easy login
  mypubip=$(/sbin/ifconfig eth0 | grep 'inet' -m1 | cut -d: -f2 | awk '{ print $2}')
  myhostnm=$(hostname)
  myfqdn=$(hostname -f)
  deets="/root/sshd_fingerprints.txt"
  touch $deets
  echo "Add to client ~/.ssh/config" >> $deets
  echo -e "host\t$myhostnm" >> $deets
  echo -e "\t\tHostName\t\t$mypubip" >> $deets
  echo -e "\t\tUser\t\t$USERA" >> $deets
  echo -e "\t\tport\t\t22" >> $deets
  echo -e " " >> $deets

  echo -e "Add to client ~/.ssh/known_hosts" >> $deets
  echo -e "\n" >> $deets
  ssh-keyscan -t rsa $mypubip >> $deets
  ssh-keyscan -t ecdsa $mypubip >> $deets
  echo -e "\n" >> $deets
  echo -e "Linode ID:\t $LINODE_ID" >> $deets
  echo -e "Lish Name:\t $LINODE_LISHUSERNAME" >> $deets
  echo -e "My IP:\t $mypubip" >> $deets
  echo -e "My Hostname:\t $myhostnm" >> $deets
  echo -e "My FQDN:\t $myfqdn" >> $deets
  echo -e " " >> $deets
  echo "SSH Server fingerprints:" >> $deets
  echo -e "\n" >> $deets
  ssh-keygen -l -f /etc/ssh/ssh_host_rsa_key >> $deets
  ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key >> $deets

  # create passwordless ssh key for root
  /usr/bin/ssh-keygen -q -N '' -t rsa -f ~/.ssh/id_rsa

  /bin/systemctl restart sshd.service >> /root/stackscript.log
  echo "[*] SSH Conf completed"
fi

######################################################################################################
# Create $USERA and install authorized_key + gen sshkeys. Add as sudoer.

if ! grep --quiet $USERA /etc/passwd; then
  touch /tmp/stackscript_user

  adduser $USERA -m -G wheel -p $PASSA -k /etc/skel/
  echo "$PASSA" | passwd $USERA --stdin

  # copy authorized_keys
  mkdir -p /home/$USERA/.ssh/
  chmod 700 /home/$USERA/.ssh
  touch /home/$USERA/.ssh/authorized_keys
  echo "$KEY1" >> /home/$USERA/.ssh/authorized_keys
  chmod 400 /home/$USERA/.ssh/authorized_keys

  touch /home/$USERA/.ssh/config
cat <<EOT >/home/$USERA/.ssh/config
host *
      ControlMaster auto
      ServerAliveInterval 30
      Compression yes
EOT

  cp /root/sshd_fingerprints.txt /home/$USERA/sshd_fingerprints.txt
  cat /root/sshd_fingerprints.txt

  chown "$USERA":"$USERA" /home/$USERA/ -R

  # create passwordless ssh key for $USERA
  su $USERA -c "/usr/bin/ssh-keygen -q -N '' -t rsa -f ~/.ssh/id_rsa"

  echo "[*] Account for $USERA setup"
fi

######################################################################################################
# When complete do final cleanup tasks then reboot

yumfin=$(pgrep yum | wc -l)
setfin=$(ls -la /tmp/stackscript_* | wc -l)

if [ $yumfin -eq 0 ] && [ $setfin -eq 4 ]; then

  # start services on boot
  systemctl enable denyhosts.service
  systemctl enable firewalld

  # Run puppet site manifest if installing
  if [ "$INSTPUPPET" == "YES" ]; then
    puppet apply /etc/puppet/manifests/site.pp --logdest /var/log/puppet/agent_autorun.log --verbose
    facter > /root/setupfiles/base_facter.txt
    mv *.rpm /root/setupfiles/
    echo "[*] puppet site manifest run"
  fi

  # Firewall - allow ssh in
  firewall-cmd --permanent --add-service=ssh

  # clean up
  mv -v /root/StackScript /root/setupfiles/
  rpm -qa > /root/setupfiles/base_packages.txt
  chmod -v 400 /root/setupfiles/*
  rm -rf /tmp/stackscript_*

  thedate=$(date)
  echo "[*] finished StackScript rebooting - $thedate" >> /root/stackscript.log
  logger "finished StackScript rebooting"
  systemctl reboot
fi

######################################################################################################
