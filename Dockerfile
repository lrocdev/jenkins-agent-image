# This image is used for jenkins-agent capable of SSH
# and has Jenkins user which is beig used for SSH into the 
# container. Jenkins user also has required rights/privillages
# to install packages and run scripts.

FROM ubuntu:18.04

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG JENKINS_AGENT_HOME=/home/${user}

ENV JENKINS_AGENT_HOME ${JENKINS_AGENT_HOME}

RUN mkdir -p "${JENKINS_AGENT_HOME}/.ssh/" \
    && addgroup --gid "${gid}" "${group}" \
# Set the home directory (h), set user and group id (u, G), set the shell, don't ask for password (D)
    # && adduser "${user}" -h "${JENKINS_AGENT_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D \
    && adduser --home "${JENKINS_AGENT_HOME}" --shell /bin/bash --uid "${uid}" --ingroup "${group}" --disabled-password "${user}" \
# Unblock user
    && passwd -u "${user}"

RUN apt-get update && \
    apt-get -qy full-upgrade && \
    apt-get install -qy git && \
# Install a basic SSH server
    apt-get install -qy openssh-server && \
# Java installation open jdk 11
    apt-get install -qy openjdk-11-jdk && \
    apt-get install -qy maven && \
    apt-get -qy autoremove && \
    apt-get install -qy bash && \
    apt-get install -qy netcat-openbsd && \
    apt-get install -qy git-lfs && \
    apt-get -qy install sudo

RUN adduser "${user}" sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Setup SSH server
RUN sed -i /etc/ssh/sshd_config \
        -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
        -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/#SyslogFacility.*/SyslogFacility AUTH/' \
        -e 's/#LogLevel.*/LogLevel INFO/' \
        -e 's/#PermitUserEnvironment.*/PermitUserEnvironment yes/' \
    && mkdir /var/run/sshd

VOLUME "${JENKINS_AGENT_HOME}" "/tmp" "/run" "/var/run"
WORKDIR "${JENKINS_AGENT_HOME}"

RUN echo "PATH=${PATH}" >> ${JENKINS_AGENT_HOME}/.ssh/environment
COPY setup-sshd /usr/local/bin/setup-sshd

RUN chown -R jenkins:jenkins ${JENKINS_AGENT_HOME} && \
    chown -R jenkins:jenkins ${JENKINS_AGENT_HOME}/.ssh

USER jenkins
# Install miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    sudo /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    sudo ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    touch .bashrc && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

USER root

ENV PATH=/opt/conda/bin:$PATH

EXPOSE 22

ENTRYPOINT ["setup-sshd"]


