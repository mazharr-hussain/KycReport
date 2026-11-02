# Validation tenancy - compartments managed by Terraform (templates/compartment)
compartments = {
  Common = {
    description = "Shared vault, keys and secrets"
  }
}

tags = {
  managed_by = "terraform"
  repo       = "mazharr-hussain/KycReport"
}
