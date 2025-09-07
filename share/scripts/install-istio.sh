#!/bin/bash

# ============================================================================
# Istio Installation Script
# ============================================================================
# Installs Istio service mesh using Helm (modern approach)
# ============================================================================

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header "Installing Istio Service Mesh with Helm"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please ensure Kubernetes is installed first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm not found. Please install Helm first."
    exit 1
fi

# Ensure kubectl uses the correct kubeconfig
if [ "$EUID" -eq 0 ]; then
    # Running as root, use admin.conf
    export KUBECONFIG=/etc/kubernetes/admin.conf
else
    # Running as vagrant user, use user kubeconfig
    export KUBECONFIG=/home/vagrant/.kube/config
fi

# Add Istio Helm repository
print_status "Adding Istio Helm repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Create istio-system namespace
print_status "Creating istio-system namespace..."
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

# Install Istio base components
print_status "Installing Istio base components..."
helm install istio-base istio/base \
  --namespace istio-system \
  --version 1.27.0

# Install Istio discovery (istiod)
print_status "Installing Istio discovery (istiod)..."
helm install istiod istio/istiod \
  --namespace istio-system \
  --version 1.27.0 \
  --set global.istioNamespace=istio-system \
  --set pilot.tolerations[0].key=node-role.kubernetes.io/control-plane \
  --set pilot.tolerations[0].operator=Exists \
  --set pilot.tolerations[0].effect=NoSchedule

# Wait for istiod to be ready
print_status "Waiting for istiod to be ready..."
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s

# Install Istio ingress gateway
print_status "Installing Istio ingress gateway..."
helm install istio-ingressgateway istio/gateway \
  --namespace istio-system \
  --version 1.27.1

# Add tolerations to the ingress gateway deployment
print_status "Adding tolerations to ingress gateway..."
kubectl patch deployment istio-ingressgateway -n istio-system -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'

# Wait for ingress gateway to be ready
print_status "Waiting for Istio ingress gateway to be ready..."
kubectl wait --for=condition=Available deployment/istio-ingressgateway -n istio-system --timeout=300s || print_warning "Ingress gateway may still be starting..."

# Install Istio addons using the simpler approach
print_status "Installing Istio addons..."

# Install Kiali using the official Istio addon
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/kiali.yaml

# Install Jaeger using the official Istio addon  
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/jaeger.yaml

# Install Grafana using the official Istio addon
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/grafana.yaml

# Install Prometheus using the official Istio addon
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/prometheus.yaml

# Add tolerations to Istio addon deployments
print_status "Adding tolerations to Istio addons..."
kubectl patch deployment kiali -n istio-system -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'
kubectl patch deployment jaeger -n istio-system -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'
kubectl patch deployment grafana -n istio-system -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'
kubectl patch deployment prometheus -n istio-system -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'

# Wait for addons to be ready
print_status "Waiting for Istio addons to be ready..."
kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=300s || print_warning "Kiali may still be starting..."
kubectl wait --for=condition=ready pod -l app=jaeger -n istio-system --timeout=300s || print_warning "Jaeger may still be starting..."
kubectl wait --for=condition=ready pod -l app=grafana -n istio-system --timeout=300s || print_warning "Grafana may still be starting..."

# Enable Istio injection for default namespace
print_status "Enabling Istio injection for default namespace..."
kubectl label namespace default istio-injection=enabled --overwrite

# Deploy sample Bookinfo application
print_status "Deploying sample Bookinfo application..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/bookinfo/platform/kube/bookinfo.yaml

# Wait for bookinfo to be ready
print_status "Waiting for Bookinfo application to be ready..."
kubectl wait --for=condition=ready pod -l app=ratings -n default --timeout=300s || print_warning "Bookinfo may still be starting..."

# Create Istio Gateway and VirtualService
print_status "Creating Istio Gateway and VirtualService..."
cat > /home/vagrant/share/bookinfo-gateway.yaml << EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http-bookinfo-gateway
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
  http:
  - match:
    - uri:
        prefix: /productpage
    - uri:
        prefix: /static
    - uri:
        prefix: /login
    - uri:
        prefix: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
EOF

kubectl apply -f /home/vagrant/share/bookinfo-gateway.yaml

print_status "Istio installation complete!"
print_status "Demo profile installed with addons:"
print_status "  - Kiali (Service Mesh Visualization)"
print_status "  - Jaeger (Distributed Tracing)"
print_status "  - Grafana (Metrics Dashboard)"
print_status "  - Bookinfo sample application"
print_status ""
print_status "To access Istio services:"
print_status "  kubectl -n istio-system port-forward svc/kiali 20001:20001"
print_status "  kubectl -n istio-system port-forward svc/grafana 3000:3000"
print_status "  kubectl -n istio-system port-forward svc/jaeger-query 16686:16686"
print_status ""
print_status "To access Bookinfo application:"
print_status "  kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80"
print_status "  Then visit: http://localhost:8080/productpage"