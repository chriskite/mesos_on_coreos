#!/bin/bash

########################################################################################################################
##
##
##  Mesos_bootstrap.sh relies on the following environment variables. The MAIN_IP and DOCKER0_IP are required and have
##  no default. You should pass them into the Docker container using the -e flag.
##
##  $MAIN_IP                - the IP of the host running Docker to which Mesos master and slave can bind (required)
##  $DOCKER0_IP             - the IP assigned to the docker0 interface onthe CoreOS host
##  $ETCD_PORT              - the port on which ETCD runs on CoreOS (default: 4001)
##
##  Usage:
##
##  When no arguments are passed into this script, it will try to dynamically configure a Mesos cluster consisting of:
##  - 1 node running a Master, Zookeeper, Marathon and a local Slave
##  - x slave nodes, depending on the amount of nodes you spin up
##
##  Discovery of the Master's IP is done using ETCD. For this to work, all nodes should be in the same ETCD cluster.
##  If automagic setup doesn't work, you can also pass in arguments and flag to set up Mesos manually:
##
##
##
##  For example, when you want to start a master
##
##  $ ./mesos_bootstrap.sh master`
##
##  When starting a slave you need to pass in the Master's Zookeeper address
##
##  $ ./mesos_bootstrap.sh slave --master=zk://172.17.8.101:2181/mesos
##
##  Starting a Marathon instance is the same as a slave
##
##  $ ./mesos_bootstrap.sh marathon --master=zk://172.17.8.101:2181/mesos --etcd=false
##
##  This script is partly based on the great work by deis:
##  https://github.com/deis/
##
## @todo: replace flags with REAL flags that don't depend on the position in cmd line
##
########################################################################################################################

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

# Set locale: this is required by the standard Mesos startup scripts
echo -e  "${normal}==> info: Setting locale to en_US.UTF-8..."
locale-gen en_US.UTF-8 > /dev/null 2>&1

# Start syslog if not started....
echo -e  "${normal}==> info: Starting syslog..."
service rsyslog start > /dev/null 2>&1


function start_slave {

    ZOOKS=`echo $1 | cut -d '=' -f2`

    # set the slave parameters
    echo ${ZOOKS} > /etc/mesos/zk
    echo docker,mesos > /etc/mesos-slave/containerizers
    echo '5mins' > /etc/mesos-slave/executor_registration_timeout
    echo /var/lib/mesos > /etc/mesos-slave/work_dir
    echo ${MAIN_IP}  > /etc/mesos-slave/ip
    echo host:${MAIN_IP}  >/etc/mesos-slave/attributes

    echo -e  "${bold}==> info: Mesos slave will coordinate with ZooKeepers ${ZOOKS}"
    echo -e  "${normal}==> info: Starting slave..."

    /usr/bin/mesos-init-wrapper slave 2>&1 &

   	# wait for the slave to start
    sleep 1 && while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$SLAVE_PORT\" && \$1 ~ tcp") ]] ; do
	    echo -e  "${normal}==> info: Waiting for Mesos slave to come online..."
	    sleep 3;
	  done

	  echo -e  "${normal}==> info: Mesos slave started on port ${SLAVE_PORT}"
}

function start_master {

    echo $MAIN_IP > /etc/mesos-master/ip
    echo in_memory > /etc/mesos/registry
    echo "zk://${ZOOKEEPERS}/mesos" > /etc/mesos/zk

    echo -e  "${normal}==> info: Starting Mesos master with ZooKeepers zk://${ZOOKEEPERS}/mesos ..."

    /usr/bin/mesos-init-wrapper master 2>&1 &

    # wait for the master to start
    sleep 1 && while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$MASTER_PORT\" && \$1 ~ tcp") ]] ; do
	    echo -e  "${normal}==> info: Waiting for Mesos master to come online..."
	    sleep 3;
    done

    echo -e  "${normal}==> info: Mesos master started on port ${MASTER_PORT}"
}

function start_marathon {
    MASTER_MARATHON="zk://${ZOOKEEPERS}/mesos"
    export MARATHON_TASK_LAUNCH_TIMEOUT=300000

    echo $MASTER_MARATHON > /etc/mesos/master

    if [ ! -d /etc/marathon/conf ]; then
        mkdir -p /etc/marathon/conf
    fi

    echo "http_callback" > /etc/marathon/conf/event_subscriber
    service marathon start > /dev/null 2>&1 &

    # while marathon runs, keep the Docker container running
    while [[ ! -z $(ps -ef | grep marathon | grep -v grep) ]] ; do
        echo -e  "${normal}==> info: `date` - Marathon with master ${MASTER_MARATHON} is running"
        sleep 10
    done

    exit 2
}

function print_usage {

    echo "not implemented yet"

}

function print_auto_mode {

    echo -e  "${normal}==> info: No flags or parameters were given, starting auto discovery..."

}

export ZOOKEEPERS=$(/usr/local/bin/zookeepers.rb $EXHIBITOR_HOST)

# Catch the command line options.
case "$1" in
    marathon)
        start_marathon $2;;
    help)
        print_usage;;
    *)
        print_auto_mode
esac

start_master

start_slave --master=zk://${ZOOKEEPERS}/mesos

# while the Master runs, keep the Docker container running
while [[ ! -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$MASTER_PORT\" && \$1 ~ tcp") ]] ; do
    echo -e  "${normal}==> info: `date` - Mesos master is running on port ${MASTER_PORT}"
    sleep 10
done

exit 1

wait

