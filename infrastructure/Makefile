# Homelab one-touch bootstrap — run from YOUR WORKSTATION (see docs/proxmox-iac.md).
#
# Requires on your PC: terraform, talosctl, kubectl, plus network reachability to
# the Proxmox API (8006), the Talos API (50000) and the Kubernetes API (6443).
#
# Usage:
#   make all        # provision infra -> bootstrap cluster -> install GitOps
#   make firewall   # 0. open inter-VLAN ports on the UDM Pro (Ansible)
#   make infra      # 1. create LXCs + Talos VMs via Proxmox API
#   make cluster    # 2. apply Talos config, bootstrap etcd, write kubeconfig
#   make gitops     # 3. install Argo CD + apply the app-of-apps root
#   make destroy    # tear everything down (talos first, then proxmox)

PROXMOX_DIR := terraform/proxmox
TALOS_DIR   := terraform/talos
ANSIBLE_DIR := ../ansible
KUBECONFIG_OUT := $(CURDIR)/kubeconfig
TALOSCONFIG_OUT := $(CURDIR)/talosconfig
ARGOCD_VERSION := stable

.PHONY: all firewall infra cluster gitops kubeconfig destroy

all: firewall infra cluster gitops

firewall:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory.ini $(ANSIBLE_DIR)/udm-firewall.yml

infra:
	terraform -chdir=$(PROXMOX_DIR) init -input=false
	terraform -chdir=$(PROXMOX_DIR) apply -auto-approve

cluster:
	terraform -chdir=$(TALOS_DIR) init -input=false
	terraform -chdir=$(TALOS_DIR) apply -auto-approve
	terraform -chdir=$(TALOS_DIR) output -raw kubeconfig  > $(KUBECONFIG_OUT)
	terraform -chdir=$(TALOS_DIR) output -raw talosconfig > $(TALOSCONFIG_OUT)
	@echo "Wrote $(KUBECONFIG_OUT) and $(TALOSCONFIG_OUT)"

kubeconfig:
	terraform -chdir=$(TALOS_DIR) output -raw kubeconfig > $(KUBECONFIG_OUT)

# Install Argo CD, then hand control to GitOps via the app-of-apps root.
gitops: kubeconfig
	KUBECONFIG=$(KUBECONFIG_OUT) kubectl create namespace argocd \
		--dry-run=client -o yaml | KUBECONFIG=$(KUBECONFIG_OUT) kubectl apply -f -
	KUBECONFIG=$(KUBECONFIG_OUT) kubectl apply -n argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	KUBECONFIG=$(KUBECONFIG_OUT) kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
	KUBECONFIG=$(KUBECONFIG_OUT) kubectl apply -f ../kubernetes/bootstrap/root-app.yaml
	@echo "Argo CD installed and root app applied. GitOps now owns the cluster."

destroy:
	-terraform -chdir=$(TALOS_DIR) destroy -auto-approve
	terraform -chdir=$(PROXMOX_DIR) destroy -auto-approve
