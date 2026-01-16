.PHONY: help bootstrap openstack-up openstack-down validate install destroy collect-metrics report clean

help: ## Show this help message
	@echo "Shift-on-Stack Lab - Makefile targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install dependencies and prepare environment
	@echo "==> Bootstrapping environment..."
	@bash hack/bootstrap.sh

openstack-up: ## Bring up OpenStack environment (MicroStack)
	@echo "==> Starting OpenStack environment..."
	@bash hack/openstack_up.sh

openstack-down: ## Tear down OpenStack environment
	@echo "==> Stopping OpenStack environment..."
	@bash hack/openstack_down.sh

validate: ## Validate OpenStack environment
	@echo "==> Validating OpenStack setup..."
	@bash hack/validate_openstack.sh

install: ## Run OpenShift installation harness
	@echo "==> Running OpenShift installation..."
	@bash hack/install_openshift.sh

destroy: ## Destroy OpenShift cluster
	@echo "==> Destroying OpenShift cluster..."
	@bash hack/destroy_cluster.sh

collect-metrics: ## Collect metrics from latest run
	@echo "==> Collecting metrics..."
	@bash hack/collect_metrics.sh

report: ## Generate metrics report
	@echo "==> Generating report..."
	@bash hack/report.sh

clean: ## Clean artifacts directory
	@echo "==> Cleaning artifacts..."
	@rm -rf artifacts/*
	@mkdir -p artifacts/logs

all: bootstrap openstack-up validate install report ## Run full workflow
