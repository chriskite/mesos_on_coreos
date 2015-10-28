FROM ubuntu:14.04

# This Dockerfile does the basic install of Mesosphere stack on CoreOS using the Ubuntu base Docker container.
# Installation details mostly copied from  https://mesosphere.io/learn/run-docker-on-mesosphere/
# Some tweaks are needed when starting this container to get Mesos running in Docker.
# 1. The CoreOS host needs to mount the Docker socket to the container
# 2. The Docker containers for Mesos master and slave need to use the --net=host option to bind directly to the host's
#    network stack.
# 3. Deimos can instruct Docker to download images, for this it needs access to the disk cache. So, we
#    need to mount the /var/lib/docker/... on CoreOS to our Ubuntu container, e.g.
#    docker run -v /var/lib/docker/btrfs/subvolumes:/var/lib/docker/btrfs/subvolumes
#
# For more info, see the accompanying README.md and mesos_bootstrap.sh script

# add mesosphere repo and keys
RUN echo "deb http://repos.mesosphere.io/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mesosphere.list

RUN sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Get things we need to add the java repo
RUN sudo apt-get -y update
RUN sudo apt-get -y install curl python-setuptools python-pip python-dev python-protobuf ruby python-software-properties software-properties-common

# add the java repo and install java 8
RUN sudo add-apt-repository ppa:webupd8team/java
RUN sudo apt-get -y update
# accept the oracle license non-interactively
RUN echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
RUN echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
RUN sudo apt-get -y install oracle-java8-installer oracle-java8-set-default

# Install and run Docker
#  We only use the client part. We bind the the docker.sock from the host to the container.
RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN echo "deb http://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
RUN apt-get -y update && apt-get -y purge lxc-docker*
RUN apt-get install -y docker-engine=1.7.1-0~trusty

# install mesos, marathon and deimos
RUN sudo apt-get -y install mesos=0.25.0-0.2.70.ubuntu1404

RUN sudo apt-get -y install marathon=0.11.1-1.0.432.ubuntu1404

ADD ./zookeepers.rb /usr/local/bin/zookeepers.rb
ADD ./mesos_bootstrap.sh /usr/local/bin/mesos_bootstrap.sh

# use the mesos_bootstrap.sh script to start

ENTRYPOINT ["/usr/local/bin/mesos_bootstrap.sh"]
