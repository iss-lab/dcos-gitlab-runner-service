FROM ubuntu:16.04

MAINTAINER TobiLG <tobilg@gmail.com>

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

ENV GITLAB_RUNNER_VERSION=11.7.0

ENV DUMB_INIT_VERSION=1.2.2

ENV DOCKER_ENGINE_VERSION=1.13.1-0~ubuntu-xenial

# Download dumb-init
ADD https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_amd64 /usr/bin/dumb-init

# Download gitlab-runner
ADD https://s3.amazonaws.com/gitlab-runner-downloads/v${GITLAB_RUNNER_VERSION}/binaries/gitlab-runner-linux-amd64 /usr/bin/gitlab-runner

# Download dcos cli
ADD https://downloads.dcos.io/binaries/cli/linux/x86-64/dcos-1.12/dcos /usr/bin/dcos

# Install components and do the preparations
# 1. Install needed packages
# 2. Install GitLab CI runner
# 3. Install mesosdns-resolver
# 4. Install Docker
# 5. Install DinD hack
# 6. Cleanup
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates apt-transport-https curl dnsutils bridge-utils lsb-release software-properties-common && \
    chmod +x /usr/bin/dumb-init && \
    chmod +x /usr/bin/gitlab-runner && \
    chmod +x /usr/bin/dcos && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    curl -sSL https://raw.githubusercontent.com/tobilg/mesosdns-resolver/master/mesosdns-resolver.sh -o /usr/local/bin/mesosdns-resolver && \
    chmod +x /usr/local/bin/mesosdns-resolver && \
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' && \
    apt-get update && \
    apt-get install -y docker-engine=${DOCKER_ENGINE_VERSION} && \
    curl -sSL https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind -o /usr/local/bin/dind && \
    chmod a+x /usr/local/bin/dind && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add wrapper script
ADD register_and_run.sh /

# Expose volumes
VOLUME ["/var/lib/docker", "/etc/gitlab-runner", "/home/gitlab-runner"]

ENTRYPOINT ["/usr/bin/dumb-init", "/register_and_run.sh"]
