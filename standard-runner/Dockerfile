FROM gitlab/gitlab-runner:ubuntu

RUN mkdir -p /mnt/mesos/sandbox

# Download dcos cli
ADD https://downloads.dcos.io/cli/releases/binaries/dcos/linux/x86-64/latest/dcos /usr/bin/dcos
RUN chmod +x /usr/bin/dcos

ADD https://downloads.mesosphere.com/dcos-commons/artifacts/0.42.1/bootstrap.zip /bootstrap.zip
RUN /usr/bin/gunzip /bootstrap.zip
RUN chmod +x /bootstrap

# Add kubectl as a container
COPY --from=lachlanevenson/k8s-kubectl:v1.14.6 /usr/local/bin/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

# Add wrapper scripts
ADD ensure_dcos_login.sh /
RUN chmod +x /ensure_dcos_login.sh
ADD register_and_run.sh /
RUN chmod +x /register_and_run.sh

ENTRYPOINT ["/usr/bin/dumb-init", "/register_and_run.sh"]