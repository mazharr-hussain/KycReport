variable "tenancy_ocid" {
  description = "Tenancy OCID (the root compartment); passed by run.sh"
  type        = string
}

variable "region" {
  description = "OCI region, e.g. me-jeddah-1; passed by run.sh"
  type        = string
}

variable "oci_profile" {
  description = "Profile in ~/.oci/config written by the token exchange"
  type        = string
  default     = "DEFAULT"
}

variable "compartments" {
  description = "Compartments by name. parent = \"root\" (tenancy) or a compartment OCID."
  type = map(object({
    description   = string
    parent        = optional(string, "root")
    enable_delete = optional(bool, false)
    tags          = optional(map(string), {})
  }))
}

variable "tags" {
  description = "Freeform tags on every compartment"
  type        = map(string)
  default     = {}
}
