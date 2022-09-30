# This image is used for jenkins-agent capable of SSH
# and has Jenkins user which is beig used for SSH into the 
# container. Jenkins user also has required rights/privillages
# to install packages and run scripts.

FROM ubuntu:18.04
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

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
    apt-get install -qy curl && \
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

RUN curl -s -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh" && \
    sh Mambaforge-Linux-x86_64.sh -b

USER root

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

ENV PATH="${PATH}:/home/jenkins/mambaforge/bin:/home/jenkins/mambaforge/condabin"

EXPOSE 22

# ENTRYPOINT ["/usr/bin/tini", "--", "setup-sshd"]
COPY entrypoint.sh /scripts/commands.sh
RUN ["chmod", "+x", "/scripts/commands.sh"]
ENTRYPOINT ["/scripts/commands.sh"]
