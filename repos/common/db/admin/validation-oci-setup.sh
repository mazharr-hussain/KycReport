#!/bin/bash
# Validation tenancy: one-time OCI / IDCS setup for GitHub OIDC login (#195). Run in OCI Cloud Shell, signed in as a
# tenancy administrator (no PAT, no API key): bash validation-oci-setup.sh
# Creates only what is missing (a re-run changes nothing):
#   1. service user github-ci-svc (no password, cannot sign in) in the Default domain
#   2. github-ci-svc as a member of group github-ci
#   3. policy: group github-ci may use the Autonomous Database family in APP_Project (start the DB, database token)
#   4. confidential app github-token-exchange (client credentials, no roles) - prints its client ID and secret once
#   5. Identity Propagation Trust github-kycreport: GitHub tokens of this repository's environment "Oracle DB Dev"
#      impersonate github-ci-svc
# Afterwards: GitHub secrets OCI_OIDC_CLIENT (client_id:client_secret) and OCI_DOMAIN_URL (printed at the end).
set -euo pipefail
DOMAIN_NAME=Default
GROUP=github-ci
SVC_USER=github-ci-svc
APP=github-token-exchange
TRUST=github-kycreport
COMPARTMENT=APP_Project
SUB='repo:mazharr-hussain/KycReport:environment:Oracle DB Dev'

D=$(oci iam domain list --all --query "data[?\"display-name\"=='$DOMAIN_NAME'].url | [0]" --raw-output)
D=${D%:443}
echo "Domain URL: $D"
req() {  # req METHOD PATH [json-body]
  if [ -n "${3:-}" ]; then printf '%s' "$3" > /tmp/body.json
    oci raw-request --http-method "$1" --target-uri "$D$2" --request-body file:///tmp/body.json
  else oci raw-request --http-method "$1" --target-uri "$D$2"; fi
}
q() { jq -rn --arg v "$1" '$v|@uri'; }  # URL-encode a SCIM filter

# 1. service user
U=$(req GET "/admin/v1/Users?filter=$(q "userName eq \"$SVC_USER\"")&attributes=id,ocid,urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User:serviceUser")
UID_=$(echo "$U" | jq -r '.data.Resources[0].id // empty')
if [ -z "$UID_" ]; then
  U=$(req POST /admin/v1/Users "$(jq -n --arg n "$SVC_USER" '{schemas:["urn:ietf:params:scim:schemas:core:2.0:User","urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User"],"urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User":{serviceUser:true},userName:$n}')")
  UID_=$(echo "$U" | jq -r '.data.id'); UOCID=$(echo "$U" | jq -r '.data.ocid')
  echo "1. created service user $SVC_USER"
else
  UOCID=$(echo "$U" | jq -r '.data.Resources[0].ocid')
  [ "$(echo "$U" | jq -r '.data.Resources[0]["urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User"].serviceUser // false')" = true ] \
    || { echo "STOP: $SVC_USER exists but is not a service user - delete it in the console and run again"; exit 1; }
  echo "1. service user $SVC_USER exists"
fi
echo "   OCID: $UOCID"

# 2. group membership
G=$(req GET "/admin/v1/Groups?filter=$(q "displayName eq \"$GROUP\"")&attributes=id,members")
GID=$(echo "$G" | jq -r '.data.Resources[0].id // empty')
[ -n "$GID" ] || { echo "STOP: group $GROUP not found in $DOMAIN_NAME"; exit 1; }
if echo "$G" | jq -e --arg u "$UID_" '.data.Resources[0].members // [] | any(.value == $u)' > /dev/null; then
  echo "2. $SVC_USER already in $GROUP"
else
  req PATCH "/admin/v1/Groups/$GID" "$(jq -n --arg u "$UID_" '{schemas:["urn:ietf:params:scim:api:messages:2.0:PatchOp"],Operations:[{op:"add",path:"members",value:[{value:$u,type:"User"}]}]}')" > /dev/null
  echo "2. added $SVC_USER to $GROUP"
fi

# 3. policy (tenancy root)
STMT="Allow group '$DOMAIN_NAME'/'$GROUP' to use autonomous-database-family in compartment $COMPARTMENT"
if oci iam policy list --compartment-id "$OCI_TENANCY" --all --query "data[?name=='github-ci-validation-db'].id | [0]" --raw-output | grep -q ocid; then
  echo "3. policy github-ci-validation-db exists"
else
  oci iam policy create --compartment-id "$OCI_TENANCY" --name github-ci-validation-db \
    --description "GitHub validation workflow: start the validation ADB and get database tokens (#195)" \
    --statements "$(jq -cn --arg s "$STMT" '[$s]')" > /dev/null
  echo "3. created policy github-ci-validation-db"
fi

# 4. confidential app (client credentials, no roles)
A=$(req GET "/admin/v1/Apps?filter=$(q "displayName eq \"$APP\"")&attributes=id,name")
CID=$(echo "$A" | jq -r '.data.Resources[0].name // empty')
if [ -z "$CID" ]; then
  A=$(req POST /admin/v1/Apps "$(jq -n --arg n "$APP" '{schemas:["urn:ietf:params:scim:schemas:oracle:idcs:App"],basedOnTemplate:{value:"CustomWebAppTemplateId"},displayName:$n,description:"GitHub OIDC token exchange (#195) - no roles",isOAuthClient:true,clientType:"confidential",allowedGrants:["client_credentials"],active:true}')")
  CID=$(echo "$A" | jq -r '.data.name')
  echo "4. created app $APP"
  echo "   client ID:     $CID"
  echo "   client secret: $(echo "$A" | jq -r '.data.clientSecret')   <- shown once: put client_id:client_secret into GitHub secret OCI_OIDC_CLIENT"
else
  echo "4. app $APP exists, client ID: $CID (secret: console > Integrated applications > $APP > OAuth configuration)"
fi

# 5. Identity Propagation Trust
T=$(req GET "/admin/v1/IdentityPropagationTrusts?filter=$(q "name eq \"$TRUST\"")&attributes=id")
if [ -n "$(echo "$T" | jq -r '.data.Resources[0].id // empty')" ]; then
  echo "5. trust $TRUST exists"
else
  req POST /admin/v1/IdentityPropagationTrusts "$(jq -n --arg n "$TRUST" --arg c "$CID" --arg r "sub eq '$SUB'" --arg u "$UOCID" '{schemas:["urn:ietf:params:scim:schemas:oracle:idcs:IdentityPropagationTrust"],name:$n,type:"JWT",active:true,allowImpersonation:true,issuer:"https://token.actions.githubusercontent.com",publicKeyEndpoint:"https://token.actions.githubusercontent.com/.well-known/jwks",oauthClients:[$c],subjectClaimName:"sub",subjectMappingAttribute:"userName",subjectType:"User",impersonationServiceUsers:[{rule:$r,value:$u}]}')" > /dev/null
  echo "5. created trust $TRUST"
fi
echo
echo "GitHub secret OCI_DOMAIN_URL = $D"
