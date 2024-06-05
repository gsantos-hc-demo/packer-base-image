# Sample Vault Agent configuration file

vault {
  address = "${vault_addr}"
}

auto_auth {
  method "aws" {
    mount_path = "admin/auth/aws"
    config = {
      type = "iam"
      role = "default"
    }
  }
}

cache {}

# telemetry {}
