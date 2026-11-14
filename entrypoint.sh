#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_URL:?GITHUB_URL wajib diisi (mis. https://github.com/org/repo atau https://github.com/org)}"

cd /home/runner/actions-runner

# Akses ke docker.sock dari host: samakan GID group
if [ -S /var/run/docker.sock ]; then
  sudo chmod 666 /var/run/docker.sock || true
fi

# Ambil registration token: pakai ACCESS_TOKEN (PAT) -> otomatis, atau REGISTRATION_TOKEN manual
if [ -n "${ACCESS_TOKEN:-}" ]; then
  case "$GITHUB_URL" in
    https://github.com/*/*) API_PATH="repos/${GITHUB_URL#https://github.com/}" ;;
    https://github.com/*)   API_PATH="orgs/${GITHUB_URL#https://github.com/}" ;;
    *) echo "GITHUB_URL tidak valid"; exit 1 ;;
  esac
  REG_TOKEN=$(curl -fsSL -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/${API_PATH}/actions/runners/registration-token" | jq -r .token)
elif [ -n "${REGISTRATION_TOKEN:-}" ]; then
  REG_TOKEN="$REGISTRATION_TOKEN"
else
  echo "Isi ACCESS_TOKEN atau REGISTRATION_TOKEN"; exit 1
fi

RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"

if [ ! -f .runner ]; then
  ./config.sh --unattended --replace \
    --url "$GITHUB_URL" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "${RUNNER_LABELS:-self-hosted,docker}" \
    --work "_work" \
    ${RUNNER_GROUP:+--runnergroup "$RUNNER_GROUP"} \
    ${EPHEMERAL:+--ephemeral}
fi

cleanup() {
  echo "Unregister runner..."
  if [ -n "${ACCESS_TOKEN:-}" ]; then
    RM_TOKEN=$(curl -fsSL -X POST \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/${API_PATH}/actions/runners/remove-token" | jq -r .token)
  else
    RM_TOKEN="$REG_TOKEN"
  fi
  ./config.sh remove --token "$RM_TOKEN" || true
}
trap 'cleanup; exit 0' SIGINT SIGTERM

./run.sh & wait $!
