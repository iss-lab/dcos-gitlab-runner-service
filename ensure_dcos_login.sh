#!/bin/sh

set -eu

dcos node || echo "Stale login found, attempting to authenticate" && dcos auth login --username $SERVICE_PRINCIPAL --private-key /gitlab-runner-private.pem && dcos node && echo "Authentication Succeded" || echo "Authentication failed, please review the configured secret for runner"