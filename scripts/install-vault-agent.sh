#!/usr/bin/env bash
set -euxo pipefail

configure_hashicorp_repo () {
  apt-get -yqq update
  apt-get -yqq install gpg
  curl \
    --silent \
    --show-error \
    --location \
    https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
}

install_vault () {
  apt-get -yqq update
  apt-get -yqq install vault
}

configure_vault_agent () {
  # Install sample configuration file
  mv "/tmp/vault-agent.hcl" "/etc/vault.d/agent.hcl"
  mv "/etc/vault.d/vault.env" "/etc/vault.d/agent.env"
  chown root:vault /etc/vault.d/{agent.hcl,agent.env}
  chmod 0640 /etc/vault.d/{agent.hcl,agent.env}

  # Install systemd service definition
  mv "/tmp/vault-agent.service" "/etc/systemd/system/vault-agent.service"
  chown root:root "/etc/systemd/system/vault-agent.service"
  chmod 0644 "/etc/systemd/system/vault-agent.service"

  # Remove Vault Server service definition and config
  rm -f /usr/lib/systemd/system/vault.service /etc/vault.d/vault.hcl

  # Reload systemd configuration
  systemctl daemon-reload
  systemctl disable vault-agent
}

main () {
  configure_hashicorp_repo
  install_vault
  configure_vault_agent
}

main
