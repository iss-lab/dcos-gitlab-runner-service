#!/usr/bin/bash

set -eu

ensure_dcos_login() {
  dcos node &> /dev/null || dcos auth login --username ${SERVICE_PRINCIPAL} --private-key /gitlab-runner-private.pem
}

handle_exit() {
  printf '%s\n' "$1" >&2
  exit 1
}

ensure_dcos_login || handle_exit 'ERR: Unable to authenticate with DC/OS.'