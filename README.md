## Elevate Labs Projects (Windows-Friendly)

This repository aggregates three DevOps-focused projects I built and documented for hands-on learning and demonstration. The projects cover canary deployments with Istio, a local DevOps sandbox with Vagrant and popular tooling, and a GitOps-enabled Spring Boot application with Kustomize overlays and CI/CD.

- `canary-deploy-isito/`: Istio-based canary deployments using the Bookinfo sample, traffic splitting, fault injection, and observability via Prometheus/Grafana/Kiali/Jaeger.
- `devops-sandbox/`: A modular Vagrant-based sandbox to spin up Docker, Kubernetes tooling, MinIO, and monitoring (Prometheus/Alertmanager), with Windows-friendly workflow.
- `gitops-project/`: A Spring Boot service managed via GitOps (Kustomize bases/overlays), built and delivered with Jenkins, and deployable via Argo CD.

The repository is designed to work smoothly on Windows using PowerShell 7 (`pwsh`). Commands below are PowerShell-compatible.

### Repository layout

```
.
├─ canary-deploy-isito/
├─ devops-sandbox/
└─ gitops-project/
```

---

## 1) Canary Deployments with Istio — `canary-deploy-isito/`

Istio canary with the Bookinfo app demonstrating:

- Canary traffic shifting (e.g., 90/10, 80/20, 50/50) between `reviews` service versions
- Destination rules, virtual services, gateways, and mTLS
- Fault injection (delays/abort) and resilience testing
- Observability (Prometheus, Grafana, Kiali, Jaeger)

### Key components

```
canary-deploy-isito/
├─ bookinfo/
│  ├─ networking/      # VirtualServices, DestinationRules, Gateways, fault injection
│  ├─ gateway-api/     # Kubernetes Gateway API flavor of routes
│  ├─ platform/kube/   # Bookinfo app manifests (Deployments, Services, DB, etc.)
│  ├─ src/             # Bookinfo service implementations + Dockerfiles
│  └─ README.md        # Scenario docs
├─ addons/             # Prometheus, Grafana, Kiali, Jaeger, Loki, Zipkin, etc.
├─ canary-manifests/   # Minimal canary VirtualService + DestinationRule examples
└─ README.md
```

### Prerequisites

- A Kubernetes cluster (KinD, Minikube, Docker Desktop Kubernetes, or managed k8s)
- `kubectl` and `helm` installed and in `PATH`
- Istioctl or Helm to install Istio
- PowerShell 7 on Windows (`pwsh`)

### Quick start (Windows PowerShell)

```powershell
# 1) Set variables
$NAMESPACE = "bookinfo"

# 2) Install Istio (example with istioctl; adjust version/path as needed)
# Download istio and add istioctl to PATH beforehand
istioctl install --set profile=demo -y

# 3) Create namespace and enable sidecar injection
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE istio-injection=enabled --overwrite

# 4) Deploy Bookinfo platform objects
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\platform\kube\bookinfo.yaml

# 5) Create DestinationRules and VirtualServices for baseline routing
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\destination-rule-all.yaml
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\virtual-service-all-v1.yaml

# 6) Expose via Gateway (choose classic or Gateway API)
# Classic Istio Gateway
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\bookinfo-gateway.yaml

# 7) Install observability addons (optional but recommended)
kubectl apply -f .\canary-deploy-isito\addons\prometheus.yaml
kubectl apply -f .\canary-deploy-isito\addons\grafana.yaml
kubectl apply -f .\canary-deploy-isito\addons\kiali.yaml
kubectl apply -f .\canary-deploy-isito\addons\jaeger.yaml
```

### Canary rollout examples

Traffic shifting for the `reviews` service:

```powershell
# Route 90% to v1 and 10% to v3
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-90-10.yaml

# Route 50% to v1 and 50% to v3
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-50-v3.yaml

# Full cutover to v3
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-v3.yaml
```

### Fault injection

```powershell
# Inject delay to test timeouts
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\virtual-service-ratings-test-delay.yaml

# Inject abort to test fallback
kubectl apply -n $NAMESPACE -f .\canary-deploy-isito\bookinfo\networking\virtual-service-ratings-test-abort.yaml
```

### Observability (ports may vary)

```powershell
# Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000
# Jaeger
kubectl port-forward -n istio-system svc/jaeger-query 16686:16686
# Prometheus
kubectl port-forward -n istio-system svc/prometheus 9090:9090
```

### Clean up

```powershell
kubectl delete namespace $NAMESPACE
istioctl uninstall -y
```

---

## 2) DevOps Sandbox — `devops-sandbox/`

A modular Vagrant environment that provisions a local sandbox with Docker, Kubernetes tooling, MinIO object storage, and monitoring (Prometheus/Alertmanager). Each module has a `provision.sh` to set up its component.

### Structure

```
devops-sandbox/
├─ Vagrantfile
├─ config.yaml                 # High-level config for the sandbox
├─ modules/
│  ├─ base/        └─ provision.sh  # Baseline packages, Docker engine, common tools
│  ├─ docker/      └─ provision.sh  # Docker-specific configuration
│  ├─ k8s/         └─ provision.sh  # Kubernetes tools (kubectl, kind/minikube)
│  ├─ minio/       └─ provision.sh  # MinIO server and client setup
│  └─ monitoring/              
│     ├─ provision.sh          # Prometheus/Alertmanager bootstrap
│     └─ prometheus/alerts.yml # Example alert rules
└─ README.md
```

### Prerequisites (Windows)

- PowerShell 7 (`pwsh`)
- VirtualBox and Vagrant installed and in `PATH`
- Hardware virtualization enabled (BIOS/UEFI)

### Bring up the sandbox

```powershell
# From repository root
Set-Location .\devops-sandbox

# Start VM(s)
vagrant up

# SSH into the primary box
vagrant ssh
```

Inside the VM, modules are provisioned via the `modules/*/provision.sh` scripts referenced by the `Vagrantfile`.

### Managing the environment

```powershell
# Halt VMs
vagrant halt

# Re-provision after changes
vagrant provision

# Destroy environment
vagrant destroy -f
```

### Monitoring

- Prometheus and Alertmanager are set up via `modules/monitoring/`
- Adjust alert rules in `modules/monitoring/prometheus/alerts.yml`

---

## 3) GitOps-Managed App — `gitops-project/`

A Spring Boot application delivered via GitOps. Uses Kustomize for environment-specific overlays (staging, production) and demonstrates CI/CD with Jenkins pipelines.

### Structure

```
gitops-project/
├─ src/main/java/...           # Spring Boot app
├─ src/main/resources/         # Config, templates, static assets
├─ manifests/
│  ├─ base/                    # Kustomize base (Deployment, Service, Ingress)
│  └─ overlays/
│     ├─ staging/              # Staging overlay + patches
│     └─ production/           # Production overlay + patches
├─ Jenkinsfile-Staging         # CI/CD pipeline for staging
├─ Jenkinsfile-Production      # CI/CD pipeline for production
├─ Dockerfile                  # Container build for the app
└─ README.md
```

### Build and test locally (Windows PowerShell)

```powershell
# Using Maven wrapper
Set-Location .\gitops-project

# Run tests
./mvnw.cmd -q test

# Build JAR
./mvnw.cmd -q package -DskipTests

# Build Docker image (requires Docker Desktop)
$IMAGE = "gitops-demo:local"
docker build -t $IMAGE .
```

### Kustomize: render manifests

```powershell
# Base
kubectl kustomize .\manifests\base | Out-File -FilePath .\target\k8s-base.yaml -Encoding utf8

# Staging overlay
kubectl kustomize .\manifests\overlays\staging | Out-File -FilePath .\target\k8s-staging.yaml -Encoding utf8

# Production overlay
kubectl kustomize .\manifests\overlays\production | Out-File -FilePath .\target\k8s-prod.yaml -Encoding utf8
```

### Deploy with kubectl (example)

```powershell
# Choose one overlay
kubectl apply -k .\manifests\overlays\staging
# or
kubectl apply -k .\manifests\overlays\production
```

### Deploy with Argo CD (GitOps)

```powershell
# Assuming Argo CD is installed in the cluster and CLI is available
# Create an Argo CD app for staging
argocd app create gitops-staging `
  --repo https://your.repo.example/elevate-labs-projects.git `
  --path gitops-project/manifests/overlays/staging `
  --dest-server https://kubernetes.default.svc `
  --dest-namespace default

# Sync
argocd app sync gitops-staging
```

### Jenkins pipelines

- `Jenkinsfile-Staging`: Build, test, containerize, and deploy to staging overlay
- `Jenkinsfile-Production`: Promotion pipeline for production overlay

Typical stages:

```
[SCM checkout] -> [Build/Test] -> [Docker Build/Push] -> [Kustomize Render] -> [Deploy (kubectl/Argo CD)]
```

---

## Common troubleshooting (Windows)

- Ensure PowerShell execution policy allows running local scripts for your current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

- Verify tools in `PATH`:

```powershell
$tools = @("kubectl", "helm", "istioctl", "docker", "vagrant", "argocd")
foreach ($t in $tools) { Write-Host ("$t: " + ((Get-Command $t -ErrorAction SilentlyContinue) ? "OK" : "NOT FOUND")) }
```

- If port-forward commands hang, ensure your firewall allows local loopback and the Kubernetes context is correct:

```powershell
kubectl config get-contexts
kubectl config use-context <your-context>
```

## License and attribution

This repository contains educational examples and upstream samples (e.g., Istio Bookinfo). Use at your own risk. Review each subproject’s `README.md` for deeper details and licensing notices.

---

## Integrated architecture: how the three projects fit together

The projects are complementary and can be used together to simulate a realistic delivery pipeline on your Windows workstation.

```
+-------------------------------- Developer Workstation (Windows + pwsh) --------------------------+
|                                                                                                  |
|  +--------------------+      +----------------------+       +-------------------------------+    |
|  | devops-sandbox/    |      | gitops-project/      |       | canary-deploy-isito/          |    |
|  | Vagrant VM(s)      |      | Spring Boot service  |       | Istio canary + observability  |    |
|  | - Docker, k8s CLI  | ---> | Dockerfile, Kustomize| ----> | Bookinfo + VS/DR + Gateways   |    |
|  | - MinIO, Monitoring|      | Manifests (base/ovl) |       | Addons: Prom, Graf, Kiali     |    |
|  +---------+----------+      +-----------+----------+       +---------------+---------------+    |
|            |                                 |                                |                  |
|            | vagrant up (pwsh)               | build/test/package (mvnw.cmd)  | kubectl apply -f |
+------------v---------------------------------v--------------------------------v------------------+
                                            Kubernetes Cluster (sandbox VM or external)
                                            -------------------------------------------------
                                            | Ingress | Istio Control Plane | App Workloads |
                                            -------------------------------------------------
                                                         ^                 ^
                                                         |                 |
                                                 Argo CD (GitOps)   Traffic shifting
                                                 syncs overlays     (reviews v1<->v3)
```

- `devops-sandbox/` provides the local VM and tooling. You can run your Kubernetes inside it (kind/k3s) and host monitoring.
- `gitops-project/` produces container images and Kustomize overlays for staging/production.
- `canary-deploy-isito/` supplies the Istio control plane usage, Bookinfo sample, and network policies for canary and fault injection.

### Flow of changes (GitOps-driven progressive delivery)

```
[Code change in gitops-project] 
     -> Jenkins pipeline builds/tests -> Docker image -> push to registry
     -> Update image tag in manifests/overlays/* (PR/merge)
     -> Argo CD detects and syncs -> Kubernetes deploys new version
     -> Istio VirtualService shifts traffic gradually (90/10 -> 50/50 -> 0/100)
     -> Observability via Prometheus/Grafana/Kiali/Jaeger validates health
```

---

## Cross-project use cases (Windows PowerShell)

### Use case A: Spin up a learning cluster and practice GitOps + Istio

```powershell
# 1) Bring up sandbox VM
Set-Location .\devops-sandbox
vagrant up

# 2) Point kubectl to the cluster (example; adjust to your setup)
# If using kind in the VM, use vagrant ssh to interact from inside the VM
vagrant ssh
# inside VM: kind create cluster --name demo

# 3) Install Istio and Bookinfo from the canary project (on host or in VM)
Set-Location ..\canary-deploy-isito
istioctl install --set profile=demo -y
kubectl create ns bookinfo
kubectl label ns bookinfo istio-injection=enabled --overwrite
kubectl apply -n bookinfo -f .\bookinfo\platform\kube\bookinfo.yaml
kubectl apply -n bookinfo -f .\bookinfo\networking\destination-rule-all.yaml
kubectl apply -n bookinfo -f .\bookinfo\networking\bookinfo-gateway.yaml

# 4) Deploy GitOps app (staging overlay)
Set-Location ..\gitops-project
./mvnw.cmd -q package -DskipTests
kubectl apply -k .\manifests\overlays\staging
```

### Use case B: Progressive delivery of a new version

```powershell
# Start with 90/10 split
kubectl apply -n bookinfo -f ..\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-90-10.yaml
# Validate with Kiali, Jaeger, and application metrics

# Move to 50/50
kubectl apply -n bookinfo -f ..\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-50-v3.yaml

# Full cutover
kubectl apply -n bookinfo -f ..\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-v3.yaml

# Rollback (example):
kubectl apply -n bookinfo -f ..\canary-deploy-isito\bookinfo\networking\virtual-service-reviews-90-10.yaml
```

### Use case C: GitOps pipeline simulation

```powershell
# Build and tag an image locally
Set-Location .\gitops-project
docker build -t gitops-demo:dev .

# Update overlay to reference your dev image (for labs/testing)
# Example: edit manifests/overlays/staging/patch.yaml to set image tag

# Render and apply to cluster
kubectl apply -k .\manifests\overlays\staging
```

### Use case D: Full observability loop

```powershell
# Port-forward dashboards
kubectl port-forward -n istio-system svc/kiali 20001:20001
kubectl port-forward -n istio-system svc/grafana 3000:3000
kubectl port-forward -n istio-system svc/jaeger-query 16686:16686
kubectl port-forward -n istio-system svc/prometheus 9090:9090

# Generate traffic (replace with your productpage URL)
# Productpage often exposed via the Istio gateway or NodePort
```

---

## Correlated diagrams

### Pipeline and runtime (end-to-end)

```
Dev (pwsh) -> Jenkins -> Registry -> Git (manifests) -> Argo CD -> Kubernetes -> Istio -> Users
     |            |           |             |               |            |         |
     |            |           |             |               |            |         +-- Traffic mgmt/telemetry
     |            |           |             |               |            +------------ Deployments/Services/Pods
     |            |           |             |               +------------------------- GitOps sync
     |            |           |             +---------------------------------------- Desired state
     |            |           +-------------------------------------------- Container image
     |            +-------------------------------------------------------- Build/Test
     +--------------------------------------------------------------------- Code change
```

### Components mapping

```
[devops-sandbox]  provides -> VM + tools + optional in-VM cluster
[gitops-project]  provides -> app code + Dockerfile + Kustomize overlays
[canary-deploy]   provides -> Istio config + Bookinfo + canary/fault-injection + addons
```

---
