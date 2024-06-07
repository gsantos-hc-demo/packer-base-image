#!/usr/bin/env bash
set -euxo pipefail

readonly SSH_MOUNT="admin/ssh"

# Ensure that the Vault cluster address is available
if [ -z "$VAULT_ADDR" ]; then
  echo "VAULT_ADDR is not set"
  exit 1
fi

# Download the SSH CA public key from Vault
curl -o /etc/ssh/vault-ca-key.pem \
    "${VAULT_ADDR}/v1/${SSH_MOUNT}/public_key"

# Add Vault CA key to sshd config
echo "TrustedUserCAKeys /etc/ssh/vault-ca-key.pem" >> /etc/ssh/sshd_config
