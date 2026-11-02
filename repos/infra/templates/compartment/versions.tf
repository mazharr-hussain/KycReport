terraform {
  required_version = ">= 1.12.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0"
    }
  }
  # OCI Object Storage state; bucket, namespace, key and region are passed by run.sh (-backend-config)
  backend "oci" {}
}

provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = var.oci_profile
  region              = var.region
}
