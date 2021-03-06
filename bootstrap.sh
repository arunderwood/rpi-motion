#!/usr/bin/env bash

SCRIPT=$(realpath -s "$0")
SCRIPTDIR=$(dirname "$SCRIPT")

assert () {
    echo "$1"
    read -r ReadInput
    if [[ "$ReadInput" == "Y" || "$ReadInput" == "y" ]]; then
        return 1
    else
        return 0
    fi
}

echo '================================================================================ '
echo '|                                                                               |'
echo '|                   RPi-Motion Installation Script                              |'
echo '|                                                                               |'
echo '================================================================================ '
echo
echo "Script: $SCRIPT"
echo "Script directory: $SCRIPTDIR"
echo

# trap "set +x; sleep 5; set -x" DEBUG

# Check whether we are running sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

CURRENT_USER=$(who am i | awk '{print $1}')

## Detecting Pi model
RpiCPU=$(/bin/grep Revision /proc/cpuinfo | /usr/bin/cut -d ':' -f 2 | /bin/sed -e "s/ //g")
if [ "$RpiCPU" == "a02082" ]; then
    echo "RapberryPi 3 detected"
    echo
    RPi3=true
else
    # RaspberryPi 2 or 1... let's say it's 2...
    echo "RapberryPi 2 detected"
    echo
    RPi3=false
fi

assert 'Do you want to set the hostname ? (Y/n) '
if [ $? == 1 ]; then
    read -r -p 'Hostname: ' NEWHOSTNAME
    echo "Setting the hostname..."
    sed -i "s/.*/$NEWHOSTNAME/g" /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t$NEWHOSTNAME/g" /etc/hosts
else
    echo "Skipping setting the hostname..."
fi

assert 'Begin Installation ? (Y/n) '
if [ $? == 1 ]; then
    echo "Beginning installation..."
else
    echo "Aborting installation"
    exit 0
fi

echo 'Performing a system update...'

apt-get -qq update
apt-get -qq install -y vim
apt-get -qq dist-upgrade

##-------------------------------------------------------------------------------------------------

if ! docker run hello-world > /dev/null ; then
    echo 'Installing Docker...'
    curl -sSL https://get.docker.com | sh
else
    echo "Docker is already installed - skipping..."
fi

if groups "$CURRENT_USER" | grep &>/dev/null '\bdocker\b'; then
    echo "$CURRENT_USER is already a member of the docker group - skipping..."
else
    echo "Adding user $CURRENT_USER to the docker group"
    usermod -aG docker "$CURRENT_USER"
fi

##-------------------------------------------------------------------------------------------------

if grep -q 'enable_uart=1' /etc/modules; then
    echo 'bcm2835-v4l2 is already enabled - skipping'
else
    echo 'Setup loading of bcm2835-v4l2 at boot time...'
    echo 'bcm2835-v4l2' >> /etc/modules
fi

##-------------------------------------------------------------------------------------------------

if [ -f /etc/systemd/system/rpi-motion.service ]; then
    echo 'rpi-motion.service is already installed - skipping'
else
    echo 'Installing rpi-motion.service...'
    cp rpi-motion.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable rpi-motion.service
fi

##-------------------------------------------------------------------------------------------------
echo "Setup complete!"
assert "Would you like to reboot now? y/n"
if [ $? == 1 ]; then
    echo "Now rebooting..."
    sleep 3
    reboot
fi
exit 0
##-------------------------------------------------------------------------------------------------
