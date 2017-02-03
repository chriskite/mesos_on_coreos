FROM registry.offers.net/devops/baseimage:1.1.1

# add mesosphere repo and keys
RUN echo "deb http://repos.mesosphere.io/ubuntu xenial main" | tee /etc/apt/sources.list.d/mesosphere.list \
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

# docker version must match coreos's docker version
RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D \
    && add-apt-repository ppa:webupd8team/java \
    && echo "deb http://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list \
    && apt-get -y update \
    && echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections \
    && apt-get -y install \
         docker-engine=1.12.6-0~ubuntu-xenial \
         marathon=1.3.9-1.0.576.ubuntu1604 \
         mesos=1.1.0-2.0.107.ubuntu1604 \
         oracle-java8-installer \
         oracle-java8-set-default \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD . /app

# use the mesos_bootstrap.sh script to start
ENTRYPOINT ["/app/bootstrap.sh"]
