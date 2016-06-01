FROM ubuntu:14.04

# add mesosphere repo and keys
RUN echo "deb http://repos.mesosphere.io/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mesosphere.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF \
    && apt-get -y update \
    && apt-get -y install \
         curl \
         python-setuptools \
         python-pip \
         python-dev \
         python-protobuf \
         ruby \
         python-software-properties \
         software-properties-common

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D \
    && add-apt-repository ppa:webupd8team/java \
    && echo "deb http://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list \
    && apt-get -y update \
    && apt-get -y purge lxc-docker* \
    && echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections \
    && apt-get -y install \
         docker-engine=1.11.1-0~trusty \
         marathon=1.1.1-1.0.472.ubuntu1404 \
         mesos=0.28.1-2.0.20.ubuntu1404 \
         oracle-java8-installer \
         oracle-java8-set-default

ADD ./zookeepers.rb /usr/local/bin/zookeepers.rb
ADD ./mesos_bootstrap.sh /usr/local/bin/mesos_bootstrap.sh

# use the mesos_bootstrap.sh script to start
ENTRYPOINT ["/usr/local/bin/mesos_bootstrap.sh"]
