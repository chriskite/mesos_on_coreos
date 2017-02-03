#!/bin/bash

# set font types
bold="\e[1;36m"
normal="\e[0m"
red="\e[0;31m"
yellow="\e[0;33m"
green="\e[0;32m"
blue="\e[0;34m"
purple="\e[0;35 m"
normal="\e[0m"

export MAIN_IP=${MAIN_IP}
export MESOS_BOOTSTRAP_VERSION=1.0

echo -e  "${bold}==> Starting Mesos/CoreOS Bootstrap on $MAIN_IP (version $MESOS_BOOTSTRAP_VERSION)${normal}"

# configure docker
export DOCKER0_IP=${DOCKER0_IP}
export DOCKER_PORT=${DOCKER_PORT:-2375}
export DOCKER="$DOCKER0_IP:$DOCKER_PORT"

# configure Mesos
export MASTER_PORT=${MASTER_PORT:-5050}
export SLAVE_PORT=${SLAVE_PORT:-5051}

MAX_RETRIES_CONNECT=10
retry=0

function start_slave {
    ZOOKS=`echo $1 | cut -d '=' -f2`

    # set the slave parameters
    echo ${ZOOKS} > /etc/mesos/zk
    echo docker,mesos > /etc/mesos-slave/containerizers
    echo '5mins' > /etc/mesos-slave/executor_registration_timeout
    echo /var/lib/mesos > /etc/mesos-slave/work_dir

    if [ ! -z "$SLAVE_ATTRIBUTES" ]
    then
      echo ${SLAVE_ATTRIBUTES} > /etc/mesos-slave/attributes
      echo -e  "${bold}==> info: Mesos slave will have attributes ${SLAVE_ATTRIBUTES}"
    fi

    if [ ! -z "$HOSTNAME" ]
    then
      echo ${HOSTNAME} > /etc/mesos-slave/hostname
    fi

    echo ${MAIN_IP}  > /etc/mesos-slave/ip

    echo -e  "${bold}==> info: Mesos slave will coordinate with ZooKeepers ${ZOOKS}"

    mkdir -p /etc/service/mesos-slave
    cp /app/run-slave.sh /etc/service/mesos-slave/run
}

function start_master {
    echo $MAIN_IP > /etc/mesos-master/ip
    echo in_memory > /etc/mesos/registry
    echo "zk://${ZOOKEEPERS}/mesos" > /etc/mesos/zk

    if [ ! -z "$HOSTNAME" ]
    then
      echo ${HOSTNAME} > /etc/mesos-master/hostname
    fi

    echo -e  "${normal}==> info: Starting Mesos master with ZooKeepers zk://${ZOOKEEPERS}/mesos ..."

    mkdir -p /etc/service/mesos-master
    cp /app/run-master.sh /etc/service/mesos-master/run
}

function start_marathon {
    MASTER_MARATHON="zk://${ZOOKEEPERS}/mesos"

    echo $MASTER_MARATHON > /etc/mesos/master
    echo $MASTER_MARATHON > /etc/mesos/zk

    if [ ! -d /etc/marathon/conf ]; then
        mkdir -p /etc/marathon/conf
    fi

    echo -e "${normal}==> info: Marathon master ${MASTER_MARATHON}"


    if [ ! -z "$MARATHON_HTTP_CREDENTIALS" ]
    then
      echo ${MARATHON_HTTP_CREDENTIALS} > /etc/marathon/conf/http_credentials
    fi

    if [ ! -z "$HOSTNAME" ]
    then
      echo ${HOSTNAME} > /etc/marathon/conf/hostname
    fi

    echo "http_callback" > /etc/marathon/conf/event_subscriber

    mkdir -p /etc/service/marathon
    cp /app/run-marathon.sh /etc/service/marathon/run
}

export ZOOKEEPERS=$(/app/zookeepers.rb $EXHIBITOR_HOST)

# Catch the command line options.
case "$1" in
    marathon)
        start_marathon $2;;
    master)
        start_master;;
    slave)
        start_slave --master=zk://${ZOOKEEPERS}/mesos;;
esac

exec /sbin/my_init
