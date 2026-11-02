#!/bin/bash
# Runs one infrastructure template (#198): run.sh <template> <env> [plan|apply]
#   template = folder under repos/infra/templates, env = folder under repos/infra/envs (values file <template>.tfvars)
# Needs: terraform, the OCI CLI, OCI_TENANCY and OCI_REGION, and ~/.oci/config with a session token (written by the
# token exchange). Creates the versioned state bucket TF_STATE_BUCKET (default tfstate) in the root when missing.
set -euo pipefail
T=${1:?template}; E=${2:?env}; ACTION=${3:-plan}
ROOT=$(cd "$(dirname "$0")" && pwd)
DIR="$ROOT/templates/$T"; VARS="$ROOT/envs/$E/$T.tfvars"
[ -d "$DIR" ] || { echo "no template $T"; exit 1; }
[ -f "$VARS" ] || { echo "no values file envs/$E/$T.tfvars"; exit 1; }
: "${OCI_TENANCY:?}" "${OCI_REGION:?}"
BUCKET=${TF_STATE_BUCKET:-tfstate}
O="--auth security_token"

NS=$(oci os ns get $O --query data --raw-output)
if ! oci os bucket get $O --bucket-name "$BUCKET" > /dev/null 2>&1; then
  oci os bucket create $O --compartment-id "$OCI_TENANCY" --name "$BUCKET" --versioning Enabled > /dev/null
  echo "created state bucket $BUCKET"
fi

terraform -chdir="$DIR" init -input=false -reconfigure \
  -backend-config="bucket=$BUCKET" -backend-config="namespace=$NS" -backend-config="key=$E/$T.tfstate" \
  -backend-config="region=$OCI_REGION" -backend-config="auth=SecurityToken" -backend-config="config_file_profile=DEFAULT"
terraform -chdir="$DIR" plan -input=false -var-file="$VARS" \
  -var "tenancy_ocid=$OCI_TENANCY" -var "region=$OCI_REGION" -out=tf.plan
if [ "$ACTION" = apply ]; then
  terraform -chdir="$DIR" apply -input=false tf.plan
  terraform -chdir="$DIR" output
fi
rm -f "$DIR/tf.plan"
