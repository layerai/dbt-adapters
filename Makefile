include include.mk
include environment.mk

.DEFAULT_GOAL:=help

install: $(INSTALL_STAMP) ## Install dependencies
$(INSTALL_STAMP): pyproject.toml poetry.lock
	@if [ -z $(POETRY) ]; then echo "Poetry could not be found. See https://python-poetry.org/docs/"; exit 2; fi
ifdef IN_VENV
	$(POETRY) install --extras $(EXTRAS)
else
	$(POETRY) install --extras $(EXTRAS) --remove-untracked
endif
	touch $(INSTALL_STAMP)

.PHONY: test
test: $(INSTALL_STAMP) ## Run unit tests
	$(POETRY) run pytest test/unit --cov .

.PHONY: e2e-test
e2e-test: $(INSTALL_STAMP) ## Run e2e tests
	$(POETRY) run pytest $(E2E_TEST_SELECTOR) --adapter $(ADAPTER) --cov .

.PHONY: format
format: $(INSTALL_STAMP) ## Apply formatters
	$(POETRY) run isort .
	$(POETRY) run black .


.PHONY: lint
lint: $(INSTALL_STAMP) ## Run all linters
	$(POETRY) run isort --check-only .
	$(POETRY) run black --check . --diff
	$(POETRY) run flake8 .
	$(POETRY) run pylint  --recursive yes .
	$(POETRY) run mypy .
	$(POETRY) run bandit -x "./test/*" -r .
	$(POETRY) lock --check

.PHONY: check
check: test lint ## Run test and lint

.PHONY: check-package-loads
check-package-loads: ## Check that we can load the package without the dev dependencies
	@rm -f $(INSTALL_STAMP)
ifdef IN_VENV
	$(POETRY) install --extras $(ADAPTER) --no-dev
else
	$(POETRY) install --extras $(ADAPTER) --no-dev --remove-untracked
endif
	$(POETRY) run python -c "import dbt"
	$(POETRY) run python -c "import dbt.adapters.layer_$(ADAPTER)"

.PHONY: publish
publish: ## Publish to PyPi - should only run in CI
	@test $${PATCH_VERSION?PATCH_VERSION expected}
	@test $${PYPI_USER?PYPI_USER expected}
	@test $${PYPI_PASSWORD?PYPI_PASSWORD expected}
	$(eval CURRENT_VERSION := $(shell $(POETRY) version --short))
	$(eval PARTIAL_VERSION=$(shell echo $(CURRENT_VERSION) | grep -Po '.*(?=\.)'))
	$(POETRY) version $(PARTIAL_VERSION).$(PATCH_VERSION)
	$(POETRY) publish --build --username $(PYPI_USER) --password $(PYPI_PASSWORD)
	$(POETRY) version $(CURRENT_VERSION)

build: test
	$(POETRY) build

.PHONY: clean
clean: ## Resets development environment.
	@echo 'cleaning repo...'
	@rm -rf `poetry env info -p`
	@rm -rf .mypy_cache
	@rm -rf .pytest_cache
	@rm -f .coverage
	@find . -type d -name '*.egg-info' | xargs rm -rf {};
	@find . -depth -type d -name '*.egg-info' -delete
	@rm -rf dist/
	@rm -f .install.stamp
	@find . -type f -name '*.pyc' -delete
	@find . -type d -name "__pycache__" | xargs rm -rf {};
	@echo 'done.'

.PHONY: help
help: ## Show this help message.
	@echo 'usage: make [target]'
	@echo
	@echo 'targets:'
	@grep --no-filename -E '^[8+0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo
