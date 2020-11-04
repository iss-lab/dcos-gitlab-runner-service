#!/bin/sh

set -eu

# Include the original entrypoint contents

# Set data directory
DATA_DIR="/etc/gitlab-runner"
CONFIG_FILE=${CONFIG_FILE:-$DATA_DIR/config.toml}

# Set custom certificate authority paths
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-$DATA_DIR/certs/ca.crt}
LOCAL_CA_PATH="/usr/local/share/ca-certificates/ca.crt"

# Create update_ca function
update_ca() {
  echo "==> Updating CA certificates..."
  cp "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}"
  update-ca-certificates --fresh > /dev/null
}

# Compare the custom CA path to the current CA path
if [ -f "${CA_CERTIFICATES_PATH}" ]; then
  # Update the CA if the custom CA is different than the current
  cmp --silent "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}" || update_ca
fi

# /Include the original entrypoint contents

if [ ! -z ${RUNNER_MUSTACHE_BASE64+x} ]; then
  rm -f ${MESOS_SANDBOX}/config.toml
  echo "${RUNNER_MUSTACHE_BASE64}" | base64 -d > ${MESOS_SANDBOX}/config.toml
  export CONFIG_TEMPLATE_GITLAB="config.toml,/etc/gitlab-runner/config.toml"
  CURRENT_DIR=$(pwd)
  cd ${MESOS_SANDBOX}
  /bootstrap -install-certs=false -print-env=false -resolve=false -resolve-hosts='' -self-resolve=false -template=true > /dev/null 2>&1
  cd ${CURRENT_DIR}
fi

# Ensure that GITLAB_INSTANCE_URL is set. Otherwise we can't register!
if [ -z ${GITLAB_INSTANCE_URL+x} ]; then
  echo "==> Need to either set GITLAB_INSTANCE_URL to the URL of the GitLab instance! Exiting..."
  exit 1
fi

# Set CI_SERVER_URL to the GITLAB_INSTANCE_URL
export CI_SERVER_URL=${GITLAB_INSTANCE_URL}

# Ensure REGISTRATION_TOKEN
if [ -z ${REGISTRATION_TOKEN+x} ]; then
    echo "==> Need to set REGISTRATION_TOKEN. You can get this token in GitLab -> Admin Area -> Overview -> Runners. Exiting..."
    exit 1
fi

# Ensure RUNNER_EXECUTOR
if [ -z ${RUNNER_EXECUTOR+x} ]; then
    echo "==> Need to set RUNNER_EXECUTOR. Please choose a valid executor, like 'shell' or 'docker' etc. Exiting..."
    exit 1
fi

# Check for RUNNER_CONCURRENT_BUILDS variable (custom defined variable)
if [ -z ${RUNNER_CONCURRENT_BUILDS+x} ]; then
    echo "==> Concurrency is set to 1"
else
    export RUNNER_REQUEST_CONCURRENCY=${RUNNER_CONCURRENT_BUILDS}
    echo "==> Concurrency is set to ${RUNNER_CONCURRENT_BUILDS}"
fi

# Derive the RUNNER_NAME from the MESOS_TASK_ID unless given
if [ -z ${RUNNER_NAME+x} ]; then
    RUNNER_NAME=${MESOS_TASK_ID}
fi

export RUNNER_NAME

# Ensure SERVICE_PRINCIPAL
if [ -z ${SERVICE_PRINCIPAL+x} ]; then
    echo "==> Need to set SERVICE_PRINCIPAL. Exiting..."
    exit 1
fi

# Enable non-interactive registration the the main GitLab instance
export REGISTER_NON_INTERACTIVE=true

# Set the RUNNER_BUILDS_DIR
export RUNNER_BUILDS_DIR=${MESOS_SANDBOX}/builds

# Set the RUNNER_CACHE_DIR
export RUNNER_CACHE_DIR=${MESOS_SANDBOX}/cache

# Set the RUNNER_WORK_DIR
export RUNNER_WORK_DIR=${MESOS_SANDBOX}/work

# Create directories
mkdir -p $RUNNER_BUILDS_DIR $RUNNER_CACHE_DIR $RUNNER_WORK_DIR

# Try logging into dcos
if [ -z ${RUNNER_SECRET+x} ]; then
    echo "==> No runner secret found"
else
    echo "==> Found secret, attempting to authenticate..."
    echo "${RUNNER_SECRET}" > /gitlab-runner-private.pem
    chmod 400 /gitlab-runner-private.pem
    dcos cluster setup https://leader.mesos --insecure --no-check --username ${SERVICE_PRINCIPAL} --private-key /gitlab-runner-private.pem
    echo "==> DC/OS CLI is authenticated!"
    dcos package install kubernetes --cli --yes
    if [ -z ${K8S_API_SERVER} ]; then
        echo "==> No Kubernetes API Server defined."
    else
        echo "==> Adding configs specific to ${K8S_CLUSTER_NAME}..."
        if [ -z ${K8S_SKIP_TLS_VERIFY} ]; then 
            dcos kubernetes cluster kubeconfig --context-name=${K8S_SA_NAME} --cluster-name=${K8S_CLUSTER_NAME} --apiserver-url=${K8S_API_SERVER}
        else    
            dcos kubernetes cluster kubeconfig --insecure-skip-tls-verify --context-name=${K8S_SA_NAME} --cluster-name=${K8S_CLUSTER_NAME} --apiserver-url=${K8S_API_SERVER} 
        fi
    fi 
    unset RUNNER_SECRET
fi

# Print the environment for debugging purposes
echo "==> Printing the environment"
env

# Launch Docker daemon
# taken from https://github.com/mesosphere/jenkins-dind-agent/blob/master/wrapper.sh

# Check for DOCKER_EXTRA_OPTS. If not present set to empty value
if [ -z ${DOCKER_EXTRA_OPTS+x} ]; then
    echo "==> Not using DOCKER_EXTRA_OPTS"
    DOCKER_EXTRA_OPTS=
else
    echo "==> Using DOCKER_EXTRA_OPTS"
    echo ${DOCKER_EXTRA_OPTS}
fi

echo "==> Launching the Docker daemon..."
# dind docker daemon --host=unix:///var/run/docker.sock --storage-driver=overlay $DOCKER_EXTRA_OPTS &
# systemctl disable docker.service
# systemctl stop docker.service
ps -ef | grep docker
/usr/bin/dockerd -H unix:///var/run/docker.sock --storage-driver=overlay $DOCKER_EXTRA_OPTS &

# Wait for the Docker daemon to start
while(! docker info > /dev/null 2>&1); do
    echo "==> Waiting for the Docker daemon to come online..."
    sleep 1
done
echo "==> Docker Daemon is up and running!"

# Termination function
_getTerminationSignal() {
    echo "Caught SIGTERM signal! Deleting GitLab Runner!"
    # Unregister (by name). See https://gitlab.com/gitlab-org/gitlab-ci-multi-runner/tree/master/docs/commands#by-name
    gitlab-runner unregister --name ${MESOS_TASK_ID}
    # Exit with error code 0
    exit 0
}

# Trap SIGTERM
trap _getTerminationSignal TERM

# Register the runner
gitlab-runner register

# Start the runner
gitlab-runner run --working-directory=${RUNNER_WORK_DIR} --listen-address $HOST:$PORT0

