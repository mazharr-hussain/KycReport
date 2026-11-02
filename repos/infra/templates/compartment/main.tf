# Compartments (#198). enable_delete = false keeps a compartment when it is removed from the values file
# (Terraform only forgets it); set it to true before removing one that must really be deleted.
resource "oci_identity_compartment" "this" {
  for_each = var.compartments

  compartment_id = each.value.parent == "root" ? var.tenancy_ocid : each.value.parent
  name           = each.key
  description    = each.value.description
  enable_delete  = each.value.enable_delete
  freeform_tags  = merge(var.tags, each.value.tags)
}
