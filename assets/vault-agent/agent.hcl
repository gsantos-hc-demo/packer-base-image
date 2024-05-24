# Sample Vault Agent configuration file

vault {
  address = "{{ vault_addr }}"
}

auto_auth {
  method "aws" {
    type       = "iam"
    mount_path = "auth/aws"
    config = {
      role = "vault-agent"
    }
  }
}

cache {}

# telemetry {}
