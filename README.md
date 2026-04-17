# GitOps Deployment Workflow
> ArgoCD + Helm + Kustomize — Git as the single source of truth for Kubernetes

![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)

---

## Architecture Overview

```
Developer pushes code
        ↓
GitHub Actions CI (test → scan → build → push image)
        ↓
CI commits new image tag to GitOps repo
        ↓
ArgoCD detects drift (Git ≠ Cluster)
        ↓
ArgoCD syncs Helm/Kustomize manifests to cluster
        ↓
Kubernetes rolling update (zero downtime)
        ↓
Slack notification + Grafana dashboard updated
```

> CI never runs `kubectl`. The cluster pulls from Git — never pushed to.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| kubectl | v1.28+ | [Install](https://kubernetes.io/docs/tasks/tools/) |
| Helm | v3.12+ | [Install](https://helm.sh/docs/intro/install/) |
| ArgoCD CLI | v2.9+ | [Install](https://argo-cd.readthedocs.io/en/stable/cli_installation/) |
| Kubernetes cluster | v1.28+ | Minikube / EKS / GKE / AKS |

---

## Execution Steps

### Step 1 — Start Cluster

```bash
minikube start --cpus=4 --memory=8192 --driver=docker
kubectl get nodes
```

### Step 2 — Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080  |  admin / <password above>
```

### Step 3 — Configure GitHub Secrets

In your **App Source repo** on GitHub, add these secrets:
```
Settings → Secrets → Actions → New repository secret

DOCKER_USERNAME   → your Docker Hub username
DOCKER_PASSWORD   → your Docker Hub password or access token
GITOPS_REPO       → bonganiajay26/gitops-deployment-workflow
GITOPS_TOKEN      → GitHub PAT with repo scope
```

### Step 4 — Apply ArgoCD Project and Applications

```bash
# Update repoURL in argocd/argocd-app.yaml to your GitOps repo
sed -i 's|YOUR_ORG|bonganiajay26|g' argocd/argocd-app.yaml
sed -i 's|YOUR_ORG|bonganiajay26|g' argocd/argocd-project.yaml

kubectl apply -f argocd/argocd-project.yaml
kubectl apply -f argocd/argocd-app.yaml

# Check sync status
kubectl get applications -n argocd
```

### Step 5 — Deploy with Helm (Manual)

```bash
# Deploy to dev
helm install python-devops-app ./helm \
  --namespace dev \
  --create-namespace \
  -f helm/values-dev.yaml

# Deploy to staging
helm install python-devops-app ./helm \
  --namespace staging \
  --create-namespace \
  -f helm/values-staging.yaml

# Deploy to production
helm install python-devops-app ./helm \
  --namespace production \
  --create-namespace \
  -f helm/values-production.yaml

# Verify deployments
kubectl get pods -n production
kubectl get svc -n production
```

### Step 6 — Deploy with Kustomize (Alternative)

```bash
# Dev
kubectl apply -k kustomize/overlays/dev/

# Staging
kubectl apply -k kustomize/overlays/staging/

# Production
kubectl apply -k kustomize/overlays/production/

# Verify
kubectl get pods -n production
```

### Step 7 — Trigger GitOps Deployment (Automated)

```bash
# Make a code change in your app source repo and push to main
# GitHub Actions will:
#   1. Run tests
#   2. Build Docker image tagged with commit SHA
#   3. Push to Docker Hub
#   4. Update image tag in this GitOps repo
# ArgoCD will detect the change and auto-sync within 3 minutes

# Watch ArgoCD sync status
watch kubectl get applications -n argocd
```

---

## Testing GitOps Features

### Test Auto-Sync (Drift Correction)

```bash
# Manually edit a deployment (simulates accidental change)
kubectl edit deployment python-devops-app -n production
# Change replicas to 1

# Watch ArgoCD auto-revert it within 3 minutes
kubectl get deployment python-devops-app -n production -w
```

### Test Rollback

```bash
# Via ArgoCD CLI
argocd app history python-devops-app-production
argocd app rollback python-devops-app-production <revision-number>

# Via Git (preferred GitOps way)
git revert HEAD
git push origin main
# ArgoCD picks up the revert and re-syncs
```

### Test Helm Upgrade

```bash
# Update image tag in values-production.yaml, then upgrade
helm upgrade python-devops-app ./helm \
  --namespace production \
  -f helm/values-production.yaml \
  --set image.tag=new-sha-here

# Check rollout status
kubectl rollout status deployment/python-devops-app -n production
```

---

## ArgoCD CLI Commands

```bash
# Login
argocd login localhost:8080 --username admin --password <password> --insecure

# List apps
argocd app list

# Sync manually
argocd app sync python-devops-app-production

# Get app details
argocd app get python-devops-app-production

# Watch sync status
argocd app wait python-devops-app-production --sync
```

---

## Cleanup

```bash
kubectl delete -f argocd/argocd-app.yaml
kubectl delete -f argocd/argocd-project.yaml
helm uninstall python-devops-app -n production
helm uninstall python-devops-app -n staging
helm uninstall python-devops-app -n dev
kubectl delete namespace argocd production staging dev
```

---

## Files

| File | Description |
|------|-------------|
| `.github/workflows/ci-gitops.yml` | CI: test → build → push → update GitOps repo |
| `argocd/argocd-app.yaml` | ArgoCD Applications for dev/staging/production |
| `argocd/argocd-project.yaml` | ArgoCD AppProject with RBAC roles |
| `argocd/argocd-notifications.yaml` | Slack alerts on sync/fail/degraded |
| `helm/Chart.yaml` | Helm chart definition |
| `helm/values*.yaml` | Per-environment values |
| `helm/templates/` | Deployment, Service, HPA, Ingress templates |
| `kustomize/` | Kustomize base + dev/staging/production overlays |
| `install-argocd.sh` | One-shot ArgoCD install + bootstrap script |
| `ARCHITECTURE.md` | Full diagram + LinkedIn post + storyboard |
