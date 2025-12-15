# ====================================================================================
#  OBSERVABILITY DEMO AUTOMATION
# ====================================================================================

# --- Tools ---
OC := oc
YQ := yq

# --- Directories ---
OPERATORS_DIR := infrastructure/00-operators
PLATFORM_DIR  := infrastructure/01-platform
APP_DIR       := infrastructure/02-demo-app
VIS_DIR       := infrastructure/03-visualization
SCRIPTS_DIR   := scripts

# --- Settings ---
_ := $(shell chmod +x $(SCRIPTS_DIR)/*.sh)

.PHONY: help check-tools deploy-all destroy-all
.PHONY: deploy-operators deploy-platform deploy-app

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

check-tools: ## Verify required tools (oc, yq) are installed
	@which $(OC) > /dev/null || (echo "❌ Error: 'oc' not found." && exit 1)
	@which $(YQ) > /dev/null || (echo "❌ Error: 'yq' not found." && exit 1)
	@echo "✅ Cluster connected: $$( $(OC) whoami --show-server )"

# ====================================================================================
#  LAYER 0: OPERATORS
# ====================================================================================

deploy-operators: check-tools ## 1. Install OTel, Loki, Tempo, and COO Operators
	@echo "🚀 [Layer 0] Installing Operators..."
	@$(OC) apply -R -f $(OPERATORS_DIR)
	@echo "⏳ Waiting for Operators to install and settle..."
	@./$(SCRIPTS_DIR)/wait-for-operators.sh

delete-operators: check-tools ## ⚠️  Uninstall Operators (Subscriptions & OperatorGroups)
	@echo "🔥 Uninstalling Operators..."
	@$(OC) delete -R -f $(OPERATORS_DIR) --ignore-not-found
	@echo "ℹ️  Note: This removes Subscriptions. Installed CSVs may remain in the cluster."

# ====================================================================================
#  LAYER 1: PLATFORM STACK (Cluster-Wide)
# ====================================================================================

deploy-platform: check-tools ## 2. Deploy UWM, Loki, Tempo, and UI Plugins
	@echo "🚀 [Layer 1] Starting Platform Deployment..."
	
	@echo "   [1/6] Configuring User Workload Monitoring..."
	@$(OC) apply -f $(PLATFORM_DIR)/00-monitoring-config.yaml

	@echo "   [2/6] Creating object storage buckets..."
	@$(OC) apply -f $(PLATFORM_DIR)/01-storage-claims.yaml

	@echo "   [3/6] Linking Storage to Platform..."
	@./$(SCRIPTS_DIR)/setup-storage.sh
	
	@echo "   [4/6] Deploying Loki, Tempo and Netobserv Stacks..."
	@$(OC) apply -f $(PLATFORM_DIR)/02-logging-stack.yaml
	@$(OC) apply -f $(PLATFORM_DIR)/03-tracing-stack.yaml
	@$(OC) apply -f $(PLATFORM_DIR)/04-netobserv-stack.yaml
	
	@echo "   [5/6] Enabling Console Plugins (Troubleshooting/Incidents)..."
	@$(OC) apply -f $(PLATFORM_DIR)/05-ui-plugins.yaml

	@echo "   [6/6] Manually create troubleshooting resources"
	@$(OC) apply -f $(PLATFORM_DIR)/06-korrel8-stack.yaml
	@$(OC) apply -f $(PLATFORM_DIR)/07-troubleshooting-panel.yaml
# 	TODO: enable plugin

	@echo "✅ Platform Stack Deployed."

# ====================================================================================
#  LAYER 2 & 3: WORKLOADS & VISUALIZATION
# ====================================================================================

deploy-app: check-tools ## 3. Deploy Quarkus, Tomcat VM, Collectors, and Perses
	@echo "🚀 [Layer 2] Deploying Application & Collectors..."
	@$(OC) apply -f $(APP_DIR)

	@echo "⏳ Waiting for Perses StatefulSet to be ready..."
	@$(OC) rollout status statefulset/perses-demo -n observability-demo --timeout=120s > /dev/null

	@echo "🔑 Configuring Perses Secret via API (Pointing to internal files)..."
	@PERSES_HOST=$$($(OC) get route perses-demo -n observability-demo -o jsonpath='{.spec.host}') && \
	echo "Targeting Perses at: https://$$PERSES_HOST" && \
	\
	echo "   [Wait] Checking if Route is accepting traffic..." && \
	for i in {1..30}; do \
		if curl -s -k --fail "https://$$PERSES_HOST/api/v1/health" > /dev/null; then \
			echo "   ✅ Route is UP!"; \
			break; \
		fi; \
		echo "   ... waiting for Router (attempt $$i/30)"; \
		sleep 2; \
	done && \
	\
	echo "   [1/2] Creating Project 'observability-demo'..." && \
	HTTP_CODE=$$(curl -k -s -o /tmp/perses_project.json -w "%{http_code}" -X POST "https://$$PERSES_HOST/api/v1/projects" \
		-H 'Content-Type: application/json' \
		-d '{"kind": "Project", "metadata": {"name": "observability-demo"}}') && \
	if [ "$$HTTP_CODE" -ge 400 ]; then \
		echo "   ⚠️  Server returned HTTP $$HTTP_CODE:"; \
		cat /tmp/perses_project.json; echo ""; \
	fi && \
	\
	echo "   [2/2] Creating Secret 'thanos-auth'..." && \
	HTTP_CODE=$$(curl -k -s -o /tmp/perses_secret.json -w "%{http_code}" -X POST "https://$$PERSES_HOST/api/v1/projects/observability-demo/secrets" \
		-H 'Content-Type: application/json' \
		-d '{"kind": "Secret", "metadata": {"name": "thanos-auth", "project": "observability-demo"}, "spec": {"authorization": {"type": "Bearer", "credentials": "", "credentialsFile": "/var/run/secrets/kubernetes.io/serviceaccount/token"}, "tlsConfig": {"ca": "", "cert": "", "key": "", "caFile": "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt", "certFile": "", "keyFile": "", "serverName": "thanos-querier.openshift-monitoring.svc", "insecureSkipVerify": false}}}') && \
	if [ "$$HTTP_CODE" -ge 400 ]; then \
		echo "   ⚠️  Server returned HTTP $$HTTP_CODE:"; \
		cat /tmp/perses_secret.json; echo ""; \
	fi
	
	@echo "📊 [Layer 3] Deploying Visualization (Datasources & Dashboards)..."
	@$(OC) apply -f $(VIS_DIR)
	@echo "✅ Workloads & Visualization Deployed."

# ====================================================================================
#  META TARGETS
# ====================================================================================

deploy-all: deploy-operators deploy-platform deploy-app ## 🌟 Install EVERYTHING from scratch
	@echo ""
	@echo "🎉 Full Stack Installation Complete!"
	@echo "   - Metrics: User Workload Monitoring (Thanos)"
	@echo "   - Logs:    OpenShift Logging (Loki)"
	@echo "   - Traces:  Distributed Tracing (Tempo)"
	@echo "   - Visuals: Perses Dashboard & OCP Console"

destroy-all: ## ⚠️  Delete App and Platform resources (Keeps Operators)
	@echo "🔥 Destroying Workload & Platform Resources..."
	@$(OC) delete -f $(APP_DIR) --ignore-not-found
	@$(OC) delete -f $(PLATFORM_DIR) --ignore-not-found
	@echo "⚠️  Note: Operators were NOT deleted to protect the cluster state. Run 'oc delete subscription ...' manually if needed."