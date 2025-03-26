# Variables
CLUSTER_NAME=ruben-cluster
NODES=3
CPUS=2
MEMORY=2g
K8S_VERSION=1.29.0
NAMESPACE=my-app-ns
DEPLOYMENT_FILE=nginx_deployment.yaml
SCALEDOBJECT_FILE=scaledobject.yaml
HELM_CHART_NAME=kedacore/keda

# Crear el clúster de Minikube
create-cluster:
	minikube start --nodes $(NODES) --cpus $(CPUS) --memory $(MEMORY) \
	--kubernetes-version $(K8S_VERSION) --profile $(CLUSTER_NAME) \
	--addons metrics-server,default-storageclass,storage-provisioner-ingress

# Etiquetar los nodos del clúster
label-nodes:
	@for node in $(shell kubectl get nodes -o=jsonpath='{.items[*].metadata.name}'); do \
		kubectl label nodes $$node category=prometheus topology.kubernetes.io/zone=eu-west-1a; \
		kubectl taint nodes $$node dedicated=prometheus:NoSchedule; \
	done

# Desplegar la aplicación Nginx en el namespace correspondiente
deploy-nginx:
	kubectl create namespace $(NAMESPACE) || true
	kubectl apply -f $(DEPLOYMENT_FILE)

# Desplegar KEDA en el namespace keda
deploy-keda:
	helm repo add kedacore https://kedacore.github.io/charts
	helm repo update
	helm install keda $(HELM_CHART_NAME) --namespace keda --create-namespace \
	--set affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=category \
	--set affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=In \
	--set affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]=prometheus \
	--set tolerations[0].key=dedicated \
	--set tolerations[0].operator=Equal \
	--set tolerations[0].value=prometheus \
	--set tolerations[0].effect=NoSchedule

# Crear un ScaledObject para Nginx en el namespace correspondiente
create-scaledobject:
	kubectl apply -f $(SCALEDOBJECT_FILE)

# Simular tráfico a Nginx usando una herramienta externa
simulate-traffic:
	ab -n 10000 -c 150 http://localhost:8080/

# Ejecutar todos los pasos necesarios para el despliegue
deploy: create-cluster label-nodes deploy-nginx deploy-keda create-scaledobject simulate-traffic

# Limpiar el clúster de Minikube
clean:
	minikube delete -p $(CLUSTER_NAME)
