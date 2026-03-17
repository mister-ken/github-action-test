#!/bin/bash

kubectl apply -f vault-auth-service-account.yaml
kubectl apply -f vault-auth-secret.yaml

vault policy write myapp-api-key-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
EOF

vault kv put secret/myapp/api-key \
  access_key='appuser' \
  secret_access_key='suP3rsec(et!'

export SA_SECRET_NAME=$(kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name')

export SA_JWT_TOKEN=$(kubectl get secret $SA_SECRET_NAME --output 'go-template={{ .data.token }}' | base64 --decode)

export SA_CA_CRT=$(kubectl config view --raw --minify --flatten --output 'jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)

export K8S_HOST=$(kubectl config view --raw --minify --flatten --output 'jsonpath={.clusters[].cluster.server}')

vault auth enable kubernetes

vault write auth/kubernetes/config \
     token_reviewer_jwt="$SA_JWT_TOKEN" \
     kubernetes_host="$K8S_HOST" \
     kubernetes_ca_cert="$SA_CA_CRT" \
     issuer="https://kubernetes.default.svc.cluster.local"

vault write auth/kubernetes/role/vault-kube-auth-role \
     bound_service_account_names=vault-auth \
     bound_service_account_namespaces=default \
     token_policies=myapp-api-key-policy \
     audience=https://kubernetes.default.svc.cluster.local \
     ttl=24h

vault read auth/kubernetes/role/vault-kube-auth-role
vault read auth/kubernetes/config
