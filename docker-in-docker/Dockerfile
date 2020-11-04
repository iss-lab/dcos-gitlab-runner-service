FROM ubuntu:16.04

LABEL TobiLG <tobilg@gmail.com> # the keyword MAINTAINER seems to be depricated

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

# ENV GITLAB_RUNNER_VERSION=v12.2.0
ENV GITLAB_RUNNER_VERSION=latest

ENV DUMB_INIT_VERSION=1.2.2

# ENV DOCKER_ENGINE_VERSION=1.13.1-0~ubuntu-xenial
ENV DOCKER_CE_VERSION=5:18.09.1~3-0~ubuntu-xenial

# Download dumb-init
ADD https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_amd64 /usr/bin/dumb-init
RUN chmod +x /usr/bin/dumb-init

# Download gitlab-runner
# ADD https://s3.amazonaws.com/gitlab-runner-downloads/${GITLAB_RUNNER_VERSION}/binaries/gitlab-runner-linux-amd64 /usr/bin/gitlab-runner
ADD https://gitlab-runner-downloads.s3.amazonaws.com/${GITLAB_RUNNER_VERSION}/binaries/gitlab-runner-linux-amd64 /usr/bin/gitlab-runner
RUN chmod +x /usr/bin/gitlab-runner

# Download dcos cli
ADD https://downloads.dcos.io/cli/releases/binaries/dcos/linux/x86-64/latest/dcos /usr/bin/dcos
RUN chmod +x /usr/bin/dcos

# Install components and do the preparations
# 1. Install needed packages
# 2. Install GitLab CI runner
# 3. Install mesosdns-resolver
# 4. Install Docker
# 5. Install DinD hack
# 6. Cleanup
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates apt-transport-https curl dnsutils bridge-utils lsb-release software-properties-common unzip && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    curl -sSL https://raw.githubusercontent.com/tobilg/mesosdns-resolver/master/mesosdns-resolver.sh -o /usr/local/bin/mesosdns-resolver && \
    chmod +x /usr/local/bin/mesosdns-resolver && \
    apt-get install -y apt-transport-https ca-certificates gnupg-agent software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    apt-key fingerprint 0EBFCD88 && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get update && \
    apt-get install -y docker-ce=${DOCKER_CE_VERSION} docker-ce-cli=${DOCKER_CE_VERSION} containerd.io && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add bootstrap binary
ADD https://downloads.mesosphere.com/dcos-commons/artifacts/0.42.1/bootstrap.zip /bootstrap.zip
RUN /usr/bin/unzip /bootstrap.zip
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
