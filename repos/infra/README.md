# OCI infrastructure templates (#198)

One Terraform template per resource type under `templates/<type>/`, one values file per environment under
`envs/<env>/<type>.tfvars`, and one script to run any of them: `run.sh <type> <env> [plan|apply]`.
Based on the module layout of oracle-devrel/oci-automation-hub, oci-starter, oci-infra-automation-scripts and
cd3-automation-toolkit (Terraform, one module per resource, values kept apart from code).

- Sign-in: GitHub OIDC -> IDCS token exchange (no API key); the OCI CLI config is written by the token exchange
  action and used by the provider and the state backend (`auth = SecurityToken`).
- State: OCI Object Storage bucket `tfstate` in the root compartment (created by `run.sh` when missing, versioned),
  one state file per environment and template: `<env>/<type>.tfstate` - so a re-run changes nothing.
- Run: Actions > "Infrastructure" > Run workflow (template, environment, plan / apply). A pull request that changes
  `repos/infra/**` runs `plan` only.

| Template | What it creates |
|---|---|
| `compartment` | compartments (name, description, parent = `root` or a compartment OCID, tags) |
