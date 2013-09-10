#!/bin/bash
# this script uses lxc to run multiple instances of SocialVPN
# this script is designed for Ubuntu 12.04 (64-bit)
#
# usage: svpn_lxc.sh username password host 1 10 svpn"

USERNAME=$1
PASSWORD=$2
XMPP_HOST=$3
CONTAINER_START=$4
CONTAINER_END=$5
MODE=$6
HOST=$(hostname)
IP_PREFIX="172.16.5"
CONTROLLER=gvpn_controller.py
START_PATH=container/rootfs/home/ubuntu/start.sh

sudo apt-get update
sudo apt-get install -y lxc tcpdump

wget -O ubuntu.tgz http://goo.gl/Ze7hYz
wget -O container.tgz http://goo.gl/XJgdtf
wget -O svpn.tgz http://goo.gl/2L6nNH

sudo tar xzf ubuntu.tgz; tar xzf container.tgz; tar xzf svpn.tgz
sudo cp -a ubuntu/* container/rootfs/
sudo mv container/home/ubuntu container/rootfs/home/ubuntu/
mv svpn container/rootfs/home/ubuntu/svpn/

if [ "$MODE" == "svpn" ]
then
    CONTROLLER=svpn_controller.py
fi

cat > $START_PATH << EOF
#!/bin/bash
SVPN_HOME=/home/ubuntu/svpn
CONFIG=\`cat \$SVPN_HOME/config\`
\$SVPN_HOME/svpn-jingle &> \$SVPN_HOME/svpn_log.txt &
python \$SVPN_HOME/$CONTROLLER \$CONFIG &> \$SVPN_HOME/controller_log.txt &
EOF

chmod 755 $START_PATH

for i in $(seq $CONTAINER_START $CONTAINER_END)
do
    container_name=container$i
    lxc_path=/var/lib/lxc
    container_path=$lxc_path/$container_name

    sudo cp -a container $container_name

    echo -n "$USERNAME $PASSWORD $XMPP_HOST $IP_PREFIX.$i" > \
             $container_name/rootfs/home/ubuntu/svpn/config

    if [ "$MODE" == "svpn" ]
    then
        echo -n "$USERNAME $PASSWORD $XMPP_HOST" > \
                 $container_name/rootfs/home/ubuntu/svpn/config
    fi

    sudo mv $container_name $lxc_path
    sudo echo "lxc.rootfs = $container_path/rootfs" >> $container_path/config
    sudo echo "lxc.mount = $container_path/fstab" >> $container_path/config
    sudo lxc-start -n $container_name -d
    sleep 30
done

