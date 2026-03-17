set shell := ["bash", "-c"]
set positional-arguments

default: all
all: version build deploy-k8s status test clean
clean-all: clean

[group('k8s')]
version:
   @echo ">> running $0"
   vault version
   docker --version
   kubectl version --client
   minikube version

[group('k8s')]
build: clean
   @echo ">> running $0"
   docker build --tag k8s-vault-client . 
   kubectl get  secret vault-auth-secret -o json | jq -r ".data.token" | base64 --decode > token

[group('k8s')]
deploy-k8s:
   @echo ">> running $0"
   minikube image load docker.io/library/k8s-vault-client:latest
   kubectl apply -f go-app.yaml
   echo "kubectl port-forward pod/vault-client 8080:8080"

[group('k8s')]
status:
   @echo ">> running $0"
   kubectl get pods

[group('exe')]
test:
   @echo ">> running $0"
   go run main.go

[group('docker')]
test-docker:
   @echo ">> running $0"
   docker run -d --name k8s-vault-client --publish 8080:8080 k8s-vault-client


[group('k8s')]
test-k8s:
   @echo ">> running $0"
   kubectl apply -f k8s-auth/go-app.yaml
   echo "kubectl port-forward pod/devwebapp 8080:8080"

[group('k8s')]
clean:
   @echo ">> running $0"
   kubectl delete -f go-app.yaml || true
   kubectl apply -f vault-auth-service-account.yaml || true
   kubectl apply -f vault-auth-secret.yaml || true
   minikube image rm docker.io/library/k8s-vault-client:latest || true
   docker stop $(docker ps -aq --filter name=k8s-vault-client) || true
   docker rm $(docker ps -aq --filter name=k8s-vault-client) || true