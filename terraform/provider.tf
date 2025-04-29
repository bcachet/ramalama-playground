terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.64.0"
    }

    ct = {
      source  = "poseidon/ct"
      version = "0.13.0"
    }
  }
}

provider "exoscale" {
  key         = var.exoscale_api_key
  secret      = var.exoscale_secret_key
  environment = "ppapi"
}
