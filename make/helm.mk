##@ Helm Charts

.PHONY: helm-build
helm-build: $(YQ) kustomize manifests ## Build the helm chart from kustomize manifests
	# Replace the controller image
	cd config/manager && $(KUSTOMIZE) edit set image controller=$(OPERATOR_IMAGE)
	# Build the helm chart templates from kustomize manifests
	$(KUSTOMIZE) build config/helm > charts/authorino-operator/templates/manifests.yaml
	V="$(BUNDLE_VERSION)" $(YQ) -i e '.version = strenv(V)' charts/authorino-operator/Chart.yaml
	V="$(CERT_MANAGER_VERSION)" $(YQ) -i e '(.dependencies[] | select(.name == "cert-manager").version) = strenv(V)' -i charts/authorino-operator/Chart.yaml
	curl -sL -o charts/authorino-operator/crds/cert-manager.crds.yaml https://github.com/cert-manager/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

.PHONY: helm-install
helm-install: $(HELM) ## Install the helm chart
	# Install the helm chart in the cluster
	$(HELM) install $(REPO) charts/$(REPO)

.PHONY: helm-uninstall
helm-uninstall: $(HELM) ## Uninstall the helm chart
	# Uninstall the helm chart from the cluster
	$(HELM) uninstall $(REPO)

.PHONY: helm-upgrade
helm-upgrade: $(HELM) ## Upgrade the helm chart
	# Upgrade the helm chart in the cluster
	$(HELM) upgrade $(REPO) charts/$(REPO)

.PHONY: helm-package
helm-package: $(HELM) ## Package the helm chart
	# Package the helm chart
	$(HELM) package charts/$(REPO)

# GitHub Token with permissions to upload to the release assets
HELM_WORKFLOWS_TOKEN ?= <YOUR-TOKEN>
# GitHub Release Asset Browser Download URL, it can be find in the output of the uploaded asset
BROWSER_DOWNLOAD_URL ?= <BROWSER-DOWNLOAD-URL>
# Github repo name for the helm charts repository
HELM_REPO_NAME ?= helm-charts

CHART_VERSION ?= $(BUNDLE_VERSION)

.PHONY: helm-sync-package-created
helm-sync-package-created: ## Sync the helm chart package to the helm-charts repo
	curl -L \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $(HELM_WORKFLOWS_TOKEN)" \
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/repos/$(ORG)/$(HELM_REPO_NAME)/dispatches \
	  -d '{"event_type":"chart-created","client_payload":{"chart":"$(REPO)","version":"$(CHART_VERSION)", "browser_download_url": "$(BROWSER_DOWNLOAD_URL)"}}'

.PHONY: helm-sync-package-deleted
helm-sync-package-deleted: ## Sync the deleted helm chart package to the helm-charts repo
	curl -L \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $(HELM_WORKFLOWS_TOKEN)" \
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/repos/$(ORG)/$(HELM_REPO_NAME)/dispatches \
	  -d '{"event_type":"chart-deleted","client_payload":{"chart":"$(REPO)","version":"$(CHART_VERSION)"}}'
