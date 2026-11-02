#!/bin/bash
# IDCS trust for GitHub OIDC (#195): (re)creates the Identity Propagation Trust that lets GitHub tokens of this
# repository's environment Oracle_OCI act as the service user github-ci-svc, then prints it. Uses the OCI CLI with
# the API key in OCI_CLI_* variables (user github-ci). Run by .github/workflows/idcs-trust.yml.
set -euo pipefail
D=${DOMAIN_URL:?}
TRUST=github-actions-trust
RULE="sub eq 'repo:mazharr-hussain/KycReport:environment:Oracle_OCI'"
get() { oci raw-request --http-method GET --target-uri "$D$1"; }
q() { jq -rn --arg v "$1" '$v|@uri'; }

SVC=$(get "/admin/v1/Users?filter=$(q 'userName eq "github-ci-svc"')&attributes=id,urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User:serviceUser" | jq -r '.data.Resources[0].id // empty')
[ -n "$SVC" ] || { echo "::error::service user github-ci-svc not found"; exit 1; }
CID=$(get "/admin/v1/Apps?filter=$(q 'displayName eq "github-token-exchange"')&attributes=name,active,allowedGrants" | tee /tmp/app.json | jq -r '.data.Resources[0].name // empty')
[ -n "$CID" ] || { echo "::error::app github-token-exchange not found"; exit 1; }
echo "service user id: $SVC   client id: $CID"
jq '.data.Resources[0] | {active, allowedGrants}' /tmp/app.json

# delete every existing trust (old names included), then create one
for id in $(get /admin/v1/IdentityPropagationTrusts | jq -r '.data.Resources[]?.id'); do
  oci raw-request --http-method DELETE --target-uri "$D/admin/v1/IdentityPropagationTrusts/$id" | jq -r '"deleted trust '"$id"': " + .status'
done
jq -n --arg n "$TRUST" --arg c "$CID" --arg r "$RULE" --arg u "$SVC" '{
  schemas:["urn:ietf:params:scim:schemas:oracle:idcs:IdentityPropagationTrust"],
  name:$n, type:"JWT", active:true, allowImpersonation:true,
  issuer:"https://token.actions.githubusercontent.com",
  publicKeyEndpoint:"https://token.actions.githubusercontent.com/.well-known/jwks",
  oauthClients:[$c], subjectClaimName:"sub", subjectMappingAttribute:"userName", subjectType:"User",
  impersonationServiceUsers:[{rule:$r, value:$u}]}' > /tmp/trust.json
oci raw-request --http-method POST --target-uri "$D/admin/v1/IdentityPropagationTrusts" --request-body file:///tmp/trust.json \
  | jq '{status, detail: .data.detail}'
echo "--- trust as stored:"
get "/admin/v1/IdentityPropagationTrusts?attributes=name,active,type,issuer,publicKeyEndpoint,oauthClients,allowImpersonation,subjectClaimName,subjectMappingAttribute,subjectType,impersonationServiceUsers,clientClaimName,clientClaimValues" \
  | jq '.data.Resources'
