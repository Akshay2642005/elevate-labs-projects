# DevOps Sandbox

A self-contained lab environment for learning and practicing DevOps tooling on local virtual machines. This sandbox uses Vagrant to provision Ubuntu VMs with modular roles such as base utilities, Docker + Portainer, a single-node Kubernetes (K3s) cluster with MetalLB and Traefik, object storage via MinIO, and a monitoring stack (Prometheus, Node Exporter, Alertmanager, Grafana).

This document explains what is included, how to configure it, how to run it, how to access services, and how to customize or troubleshoot the environment.

---

## Overview and Architecture

- **Vagrant + Provider**: Automates creation of Ubuntu Linux VMs (box `ubuntu/focal64`). Default provider is VirtualBox; others are supported by Vagrant.
- **Host manager**: Hostname entries are managed so you can refer to machines by name. (Requires the `vagrant-hostmanager` plugin.)
- **Private network**: VMs are placed on a private network (default base subnet `192.168.56.0/24`). Each VM gets a static IP.
- **Modular roles**: Each VM is assigned a role; a base provisioning script runs on all VMs, and an optional role-specific script runs afterward.
  - `base`: Common CLI tools and OS updates
  - `docker`: Docker Engine + Portainer (UI)
  - `k8s`: K3s (single-node Kubernetes) + MetalLB + Traefik + Helm
  - `minio`: MinIO object storage + console
  - `monitoring`: Prometheus + Node Exporter + Alertmanager + Grafana


Provisioning flow (per VM):

1. Load configuration from `config.yaml`
2. Create VM with hostname, CPU, RAM, IP
3. Run `modules/base/provision.sh`
4. Run `modules/<role>/provision.sh` if present

---

## Repository Layout

```
devops-sandbox/
├── Vagrantfile                    # Vagrant configuration and provisioning logic
├── config.yaml                    # Editable configuration: provider, VMs, roles, resources
└── modules/                       # Provisioners grouped by role
    ├── base/
    │   └── provision.sh          # OS updates and base CLI tooling
    ├── docker/
    │   └── provision.sh          # Docker Engine + Portainer
    ├── k8s/
    │   └── provision.sh          # K3s + MetalLB + Traefik + Helm
    ├── minio/
    │   └── provision.sh          # MinIO server and console via systemd
    └── monitoring/
        ├── provision.sh          # Prometheus + Node Exporter + Alertmanager + Grafana
        ├── alertmanager/
        │   └── config.yml        # Alertmanager receivers and routing (example)
        └── prometheus/
            ├── alerts.yml        # Prometheus alert rules (example)
            └── prometheus.yml    # Prometheus server configuration
```

---

## Prerequisites

- Vagrant (`vagrant --version`)
- Virtualization provider (default is **VirtualBox**). Alternatives: VMware Desktop, Hyper-V, libvirt (KVM). Ensure the provider matches `config.yaml`.
- Vagrant plugin for host entries:
  - `vagrant plugin install vagrant-hostmanager`
- Sufficient resources: At least 4 CPU cores and 8 GB RAM recommended for a single VM with the `k8s` role; more for multiple roles/VMs.
- Windows users: Ensure Hyper-V is disabled if using VirtualBox; only one hypervisor can control VT-x at a time.

Optional (inside VMs or on your host):

- kubectl, helm (handy for Kubernetes operations)

> Tip: If you switch providers (e.g., from VirtualBox to Hyper-V), destroy existing VMs before changing `provider` in `config.yaml`.

---

## Configuration: `config.yaml`

Use `config.yaml` to define the provider, number of VMs, resource defaults, network, and per-VM roles.

Default example provided:

```yaml
provider: virtualbox # options: virtualbox, libvirt, vmware_desktop, hyperv
num_vms: 1 # number of machines
subnet: 192.168.56 # base subnet for private networking
default_ram: 4096 # default RAM in MB
default_cpus: 2 # default CPU cores

roles:
  - hostname: node01
    role: k8s
    ram: 4096
    cpus: 2
```

- **provider**: Choose a provider installed on your system.
- **num_vms**: Number of VMs to create. The `roles` array should include one entry per VM.
- **subnet**: Base private network, VM IPs become `${subnet}.(10 + index)` if not overridden.
- **default_ram / default_cpus**: Defaults applied when not specified per-VM.
- **roles[n]**: Per-VM settings: `hostname`, `role`, optionally override `ram`, `cpus`, and `ip`.

Multiple VM example:

```yaml
provider: virtualbox
num_vms: 3
subnet: 192.168.56
default_ram: 2048
default_cpus: 2

roles:
  - hostname: mon1
    role: monitoring
    ram: 2048
    cpus: 2
    ip: 192.168.56.21
  - hostname: k8s1
    role: k8s
    ram: 4096
    cpus: 2
    ip: 192.168.56.22
  - hostname: s3
    role: minio
    ram: 2048
    cpus: 2
    ip: 192.168.56.23
```

Notes:

- Valid roles are defined in the `Vagrantfile`: `monitoring`, `docker`, `k8s`, `minio`, `aws`, `base`. If a module script for a role is missing, provisioning proceeds with a log message indicating it was skipped.
- The guest OS is Ubuntu 20.04 (Focal). Hostnames and hardware names are applied per VM.

---

## What Each Role Installs

### base

Common baseline configuration for every VM:

- System update and upgrade
- CLI tools: `git`, `curl`, `wget`, `vim`, `net-tools`, `htop`, `unzip`
- Transport and CA utilities: `software-properties-common`, `apt-transport-https`, `ca-certificates`, `lsb-release`

### docker

Container runtime and a UI for managing containers:

- Docker CE, Docker CLI, containerd, Buildx, and Compose plugin
- Adds user `vagrant` to the `docker` group
- Portainer Community Edition in Docker:
  - Portainer UI: host port `9000` (HTTP) and `9443` (HTTPS) → container ports


### k8s

Single-node Kubernetes via K3s and a minimal ingress + load balancing stack:

- K3s server install with Traefik and ServiceLB disabled (we replace them):
  - Kubeconfig written to `/home/vagrant/.kube/config` (mode 644)
- Waits for the API and node readiness
- Installs Helm 3
- Configures MetalLB:
  - Detects VM subnet and allocates IP pool `${SUBNET}.240`–`${SUBNET}.250`
  - Applies `IPAddressPool` and `L2Advertisement`
- Installs Traefik via Helm in `kube-system`


### minio

S3-compatible object storage with a web console:

- Installs MinIO server and the `mc` client
- Creates a systemd service for MinIO
- Default ports:
  - S3 API: `:9000`
  - Console: `:9001`


### monitoring

System and service monitoring stack:

- Prometheus (installed to `/opt/prometheus`, binaries to `/usr/local/bin`, systemd service)
- Node Exporter (binary to `/usr/local/bin`, systemd service)
- Alertmanager (installed to `/opt/alertmanager`, config to `/etc/alertmanager.yml`, systemd service)
- Grafana OSS (installed via APT repository, `grafana-server` systemd service)
- Prometheus configuration:
  - Scrape interval `15s`
  - Scrapes `prometheus` on `localhost:9090` and `node_exporter` on `localhost:9100`
  - Loads alert rules from `alerts.yml`
- Example alerts included:
  - High CPU usage (> 80% for 2 minutes)
  - Low disk space (< 10% free)
- Alertmanager example receiver: email (placeholder values in `modules/monitoring/alertmanager/config.yml`)


Security note: Do not commit real SMTP credentials; use environment variables or a secrets manager in real setups.

---

## Networking and Exposed Ports

Per the `Vagrantfile`, forwarded ports are set up for convenience on certain roles:

- `monitoring` role VM:
  - Prometheus: host `9090` → guest `9090`
  - Grafana: host `3000` → guest `3000`
  - Alertmanager: host `9093` → guest `9093`
- `docker` role VM:
  - Portainer: host `9000` → guest `9000` (HTTP)
- `minio` role VM:
  - MinIO Console: host `9001` → guest `9001`

Kubernetes (k8s role):

- MetalLB provides LoadBalancer IPs from `${SUBNET}.240`–`${SUBNET}.250` inside the private network.
- Traefik serves as the ingress controller. Exposed LoadBalancer IPs are reachable from the host if routing to the private network is configured by Vagrant (default for host-only networks).

---

## Getting Started

1. Install prerequisites (Vagrant, VirtualBox) and the hostmanager plugin:

   ```bash
   vagrant plugin install vagrant-hostmanager
   ```

2. Review and customize `devops-sandbox/config.yaml` as needed.
3. From the `devops-sandbox` directory, bring up the environment:

   ```bash
   vagrant up
   ```

4. SSH into a VM (example: the first VM defined):

   ```bash
   vagrant ssh node01
   ```


Stopping and destroying:

```bash
vagrant halt          # stop VMs
vagrant destroy -f    # remove VMs
```

Re-provision after changing scripts:

```bash
vagrant provision node01
```

---

## Verifying Each Role

### base

- Check common tools:

  ```bash
  git --version && curl --version && vim --version
  ```

### docker

- Check Docker and Portainer:

  ```bash
  docker version
  docker ps
  ```

- Visit Portainer at `http://localhost:9000` (or the VM's IP if not using forwarded ports). Initialize the admin password on first login.

### k8s

- Confirm node is Ready:

  ```bash
  export KUBECONFIG=/home/vagrant/.kube/config
  kubectl get nodes
  ```

- Check MetalLB components:

  ```bash
  kubectl get all -n metallb-system
  ```

- Confirm Traefik is running:

  ```bash
  kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
  ```

### minio

- Check services:

  ```bash
  systemctl status minio
  ```

- Access console at `http://localhost:9001` (or VM IP:9001). Create a bucket and test with `mc`.

### monitoring

- Prometheus:

  ```bash
  systemctl status prometheus
  curl -s localhost:9090/-/ready
  ```

- Node Exporter:

  ```bash
  systemctl status node_exporter
  curl -s localhost:9100/metrics | head
  ```

- Alertmanager:

  ```bash
  systemctl status alertmanager
  curl -s localhost:9093
  ```

- Grafana:

  ```bash
  systemctl status grafana-server
  ```

- Access UIs:
  - Prometheus: `http://localhost:9090`
  - Alertmanager: `http://localhost:9093`
  - Grafana: `http://localhost:3000` (default login `admin` / `admin` on first run; change it)

---

## Customizing and Extending

- Add a new VM: Increase `num_vms` and add another entry under `roles` in `config.yaml`.
- Change resources: Adjust `ram` and `cpus` per VM.
- Pin versions: In module scripts, replace `latest` tags and variables (e.g., `PROM_VERSION`, `NODE_EXPORTER_VERSION`, `ALERTMANAGER_VERSION`) with desired versions.
- Add a new role: Create `modules/<new-role>/provision.sh`, add the role name to the `roles` list in `Vagrantfile` if not already present, and reference it in `config.yaml`.
- Kubernetes addons: Use `helm` and `kubectl` within a `k8s` VM to install charts (e.g., ingress routes, monitoring agents, etc.).
- Prometheus targets: Edit `modules/monitoring/prometheus/prometheus.yml` to add scrape jobs for additional services. Re-provision or reload Prometheus.
- Alerting: Update `modules/monitoring/alertmanager/config.yml` with real receivers (email/webhook/Slack). Restart Alertmanager to apply changes.

---

## Troubleshooting

- Provider issues (VirtualBox, Hyper-V, VMware): Ensure only one hypervisor is active. On Windows, disable Hyper-V when using VirtualBox.
- Hostmanager plugin: If host entries are not updating, run:

  ```bash
  vagrant plugin install vagrant-hostmanager
  vagrant hostmanager
  ```

- Provisioning idempotency: Scripts try to be safe to re-run. If a provisioning step fails, fix the root cause and run:

  ```bash
  vagrant provision <vm-name>
  ```

- Kubernetes not Ready:
  - Check services: `sudo journalctl -u k3s -f`
  - Verify kubeconfig: `/home/vagrant/.kube/config`
  - Ensure enough CPU/RAM allocated
- MetalLB IP pool: Pool defaults to `${SUBNET}.240-250`. Confirm your private network does not conflict with other host routes.
- Grafana/Prometheus/Alertmanager not reachable on host ports:
  - Verify the VM has the `monitoring` role
  - Confirm services are active: `systemctl status <service>`
  - Check forwarded ports in `Vagrantfile`
- Docker permission denied:
  - Log out and back in (or `newgrp docker`) after adding user to `docker` group
- MinIO credentials: This setup starts MinIO with default parameters. Configure access keys using environment variables or systemd `Environment` entries for production-like scenarios.

---
## Security Considerations

This sandbox is for local learning and experimentation. It is not hardened for production:

- Default ports are exposed to the host; do not bind to public interfaces.
- Replace placeholder credentials in Alertmanager and set credentials for MinIO and Portainer.
- Keep software up to date; consider pinning versions.
- Limit resource exposure when running untrusted workloads.

---

## Clean Up

Tear down all VMs and remove associated disks:

```bash
vagrant destroy -f
```

If you need to reclaim VirtualBox storage, also remove any leftover VMs/disks from the VirtualBox UI.

---

## References

- Vagrant: <https://www.vagrantup.com/>
- VirtualBox: <https://www.virtualbox.org/>
- Docker: <https://www.docker.com/>
- Portainer: <https://www.portainer.io/>
- K3s: <https://k3s.io/>
- Helm: <https://helm.sh/>
- MetalLB: <https://metallb.universe.tf/>
- Traefik: <https://traefik.io/>
- MinIO: <https://min.io/>
- Prometheus: <https://prometheus.io/>
- Alertmanager: <https://prometheus.io/docs/alerting/latest/alertmanager/>
- Grafana: <https://grafana.com/>
