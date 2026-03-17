# k8s auth with SDK


```

vault server -dev -dev-root-token-id root

kaf manifests/vault-auth-service-account.yaml
kaf manifests/vault-auth-secret.yaml
kubectl get  secret vault-auth-secret -o json | jq -r ".data.token" > token
```


```
vault auth enable kubernetes

vault kv put secret/my-secret-password password=Hashi123

export TOKEN_REVIEW_JWT=$(kubectl get secret vault-auth-secret --output='go-template={{ .data.token }}' | base64 --decode)

export KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')

kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode > kube_ca_cert

vault write auth/kubernetes/config \
 	token_reviewer_jwt=${TOKEN_REVIEW_JWT} \
    kubernetes_host=${KUBE_HOST} \
    kubernetes_ca_cert=@kube_ca_cert \
    issuer="kubernetes/serviceaccount"

vault write auth/kubernetes/role/dev-role-k8s \
   policies="dev-policy" \
   bound_service_account_names="vault-auth" \
   bound_service_account_namespaces="default"

vault policy write  dev-policy - <<EOF
path "secret/data/myapp/*" {
   capabilities = ["read", "list"]
}
EOF
```

```
kubectl port-forward pod/vault-client 8080:8080 
```