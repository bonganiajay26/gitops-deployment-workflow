#!/bin/bash
# install-argocd.sh — Install ArgoCD and bootstrap GitOps

set -e

echo "=== Installing ArgoCD ==="

# Create ArgoCD namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo ""
echo "=== ArgoCD installed ==="
echo ""

# Get the initial admin password
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# Port-forward to access UI
echo ""
echo "Access ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo "  Username: admin"
echo ""

# Apply ArgoCD project and applications
echo "=== Deploying ArgoCD Applications ==="
kubectl apply -f argocd/argocd-project.yaml
kubectl apply -f argocd/argocd-app.yaml
kubectl apply -f argocd/argocd-notifications.yaml

echo ""
echo "=== GitOps Bootstrap Complete ==="
echo "ArgoCD will now watch your GitOps repo and auto-sync all environments."
echo ""
echo "Check sync status:"
echo "  kubectl get applications -n argocd"
