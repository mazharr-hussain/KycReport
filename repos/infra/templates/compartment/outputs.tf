output "compartment_ids" {
  description = "Compartment OCIDs by name"
  value       = { for k, c in oci_identity_compartment.this : k => c.id }
}
