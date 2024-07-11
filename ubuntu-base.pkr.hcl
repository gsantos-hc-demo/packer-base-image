packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }

    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Variables --------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region in which the AMI is created."
  type        = string
  default     = "us-east-1"
}

variable "aws_regions" {
  description = "List of AWS regions to which the AMI is copied."
  type        = list(string)
  default     = []
}

variable "aws_orgs" {
  description = "List of AWS organization IDs to which the AMI is shared."
  type        = list(string)
  default     = []
}

variable "aws_accounts" {
  description = "List of AWS account IDs to which the AMI is shared."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "Instance type to use for the build instance."
  type        = string
  default     = "t3.large"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "vault_addr" {
  description = "Vault address to use for the Vault Agent."
  type        = string
}

# Provider Config. & Source AMI ------------------------------------------------
data "amazon-ami" "ubuntu" {
  most_recent = true
  region      = var.aws_region
  owners      = ["099720109477"] # Canonical
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }
}

# AMI Config. ------------------------------------------------------------------
source "amazon-ebs" "base" {
  # Things you'd want to include in a production-ready image:
  # - Custom VPC and/or Security Groups for the build instance
  # - Encryption with Customer-Managed KMS Keys

  # AMI Settings
  ami_name        = "ubuntu-base-{{timestamp}}"
  ami_description = "Base Ubuntu 22.04 LTS AMI with security hardening"
  ami_users       = var.aws_accounts
  ami_org_arns    = var.aws_orgs
  ami_regions     = var.aws_regions
  tags = {
    Name           = "ubuntu-base-{{timestamp}}"
    SourceAMI      = "{{ .SourceAMI }}"
    SourceAMIOwner = "{{ .SourceAMIOwner }}"
  }

  # Security
  imds_support = "v2.0" # Enforce IMDSv2.0

  # Run Configuration
  region        = var.aws_region
  source_ami    = data.amazon-ami.ubuntu.id
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  # Use GP3 root storage device
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }
}

# Build Config. ----------------------------------------------------------------
build {
  hcp_packer_registry {
    bucket_name = "ubuntu-base"
    description = "Base Ubuntu 22.04 LTS AMI with security hardening"
    bucket_labels = {
      team = "platform"
      os   = "ubuntu"
    }
    build_labels = {
      release = "22.04"
    }
  }

  sources = [
    "source.amazon-ebs.base",
  ]

  # Install Vault Agent
  provisioner "file" {
    destination = "/tmp/vault-agent.hcl"
    content = templatefile("${path.root}/assets/vault-agent/agent.hcl", {
      vault_addr = var.vault_addr
    })
  }

  provisioner "file" {
    source      = "${path.root}/assets/vault-agent/vault-agent.service"
    destination = "/tmp/vault-agent.service"
  }

  provisioner "shell" {
    execute_command = "sudo -E sh -x -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "${path.root}/scripts/install-vault-agent.sh",
      "${path.root}/scripts/configure-vault-ssh-ca.sh",
    ]

    env = {
      VAULT_ADDR = var.vault_addr
    }
  }

  # Apply security hardening
  provisioner "ansible" {
    playbook_file = "${path.root}/assets/ansible-playbook.yml"
  }
}
