terraform {
  required_providers {
    hydra = {
      version = "~> 0.1"
      source  = "DeterminateSystems/hydra"
    }
  }
}

variable "project_path" {
  type = string
}

variable "nonce" {
  type = string
}

provider "hydra" {
  host     = "http://localhost:3000"
  username = "alice"
  password = "foobar"
}

resource "hydra_project" "example" {
  name         = "migration-example"
  display_name = "Migration Example"
  description  = "Migrating from one backing store to another."
  homepage     = ""
  owner        = "alice"
  enabled      = true
  visible      = true
}

resource "hydra_jobset" "project" {
  project     = hydra_project.example.name
  state       = "enabled"
  visible     = true
  name        = "migration"
  type        = "legacy"
  description = "migration example jobset"

  nix_expression {
    file  = "default.nix"
    input = "example"
  }

  check_interval    = 1
  scheduling_shares = 3000
  keep_evaluations  = 3

  email_notifications = false

  input {
    name              = "system"
    type              = "string"
    value             = "x86_64-linux"
    notify_committers = false
  }

  input {
    name              = "example"
    type              = "path"
    value             = var.project_path
    notify_committers = false
  }

  input {
    name              = "nonce"
    type              = "string"
    value             = var.nonce
    notify_committers = false
  }
}
