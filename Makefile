ifneq (,)
.error This Makefile requires GNU Make.
endif

.PHONY: build rebuild lint test _test-php-cs-fixer-version _test-php-version _test-run tag pull login push enter

CURRENT_DIR = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

DIR = .
FILE = Dockerfile
IMAGE = cytopia/php-cs-fixer
TAG = latest

PHP = latest
PCF = latest

build:
ifeq ($(PCF),1)
ifeq ($(PHP),latest)
	@# PHP CS Fixer version 1 goes only up to PHP 7.1
	docker build --build-arg PHP=7.1-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
else
	docker build --build-arg PHP=$(PHP)-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
endif
else
ifeq ($(PHP),latest)
	docker build --build-arg PHP=7-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
else
	docker build --build-arg PHP=$(PHP)-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
endif
endif

rebuild: pull
ifeq ($(PCF),1)
ifeq ($(PHP),latest)
	@# PHP CS Fixer version 1 goes only up to PHP 7.1
	docker build --no-cache --build-arg PHP=7.1-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
else
	docker build --no-cache --build-arg PHP=$(PHP)-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
endif
else
ifeq ($(PHP),latest)
	docker build --no-cache --build-arg PHP=7-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
else
	docker build --no-cache --build-arg PHP=$(PHP)-cli-alpine --build-arg PCF=$(PCF) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)
endif
endif

lint:
	@docker run --rm -v $(CURRENT_DIR):/data cytopia/file-lint file-cr --text --ignore '.git/,.github/,tests/' --path .
	@docker run --rm -v $(CURRENT_DIR):/data cytopia/file-lint file-crlf --text --ignore '.git/,.github/,tests/' --path .
	@docker run --rm -v $(CURRENT_DIR):/data cytopia/file-lint file-trailing-single-newline --text --ignore '.git/,.github/,tests/' --path .
	@docker run --rm -v $(CURRENT_DIR):/data cytopia/file-lint file-trailing-space --text --ignore '.git/,.github/,tests/' --path .
	@docker run --rm -v $(CURRENT_DIR):/data cytopia/file-lint file-utf8 --text --ignore '.git/,.github/,tests/' --path .
	@docker run --rm -v $(CURRENT_DIR):/data cytopia/file-lint file-utf8-bom --text --ignore '.git/,.github/,tests/' --path .

test:
	@$(MAKE) --no-print-directory _test-php-cs-fixer-version
	@$(MAKE) --no-print-directory _test-php-version
	@$(MAKE) --no-print-directory _test-run

_test-php-cs-fixer-version:
	@echo "------------------------------------------------------------"
	@echo "- Testing correct phpcs version"
	@echo "------------------------------------------------------------"
	@echo "Fetching latest version from GitHub"; \
	if [ "$(PCF)" = "latest" ]; then \
		LATEST="$$( \
			curl -L -sS https://github.com/FriendsOfPHP/PHP-CS-Fixer/releases \
				| tac | tac \
				| grep -Eo 'tag/v?[.0-9]+?\.[.0-9]+\"' \
				| grep -Eo '[.0-9]+' \
				| sort -V \
				| tail -1 \
		)"; \
		echo "Testing for latest: $${LATEST}"; \
		if ! docker run --rm $(IMAGE) --version | grep -E "^PHP CS Fixer (version)?$${LATEST}"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	else \
		echo "Testing for tag: $(PCF).x.x"; \
		if ! docker run --rm $(IMAGE) --version | grep -E "^PHP CS Fixer (version[[:space:]])?$(PCF)\.[.0-9]+"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	fi; \
	echo "Success"; \

_test-php-version:
	@echo "------------------------------------------------------------"
	@echo "- Testing correct PHP version"
	@echo "------------------------------------------------------------"
	@if [ "$(PCF)" = "1" ] && [ "$(PHP)" = "latest" ]; then \
		echo "Testing for tag: 7.1.x"; \
		if ! docker run --rm --entrypoint=php $(IMAGE) --version | head -1 | grep -E "^PHP[[:space:]]+7\.1\.[.0-9]+[[:space:]]"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	elif [ "$(PHP)" = "latest" ]; then \
		echo "Fetching latest version from GitHub"; \
		LATEST="$$( \
		curl -L -sS https://github.com/php/php-src/releases \
			| tac | tac \
			| grep -Eo '/php-[.0-9]+?\.[.0-9]+"' \
			| grep -Eo '[.0-9]+' \
			| sort -V \
			| tail -1 \
		)"; \
		echo "Testing for latest: $${LATEST}"; \
		if ! docker run --rm --entrypoint=php $(IMAGE) --version | head -1 | grep -E "^PHP[[:space:]]+$${LATEST}[[:space:]]"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	else \
		echo "Testing for tag: $(PHP).x"; \
		if ! docker run --rm --entrypoint=php $(IMAGE) --version | head -1 | grep -E "^PHP[[:space:]]+$(PHP)\.[.0-9]+[[:space:]]"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	fi; \
	echo "Success"; \

_test-run:
	@echo "------------------------------------------------------------"
	@echo "- Testing phpcs (success)"
	@echo "------------------------------------------------------------"
	@if ! docker run --rm -v $(CURRENT_DIR)/tests/ok:/data $(IMAGE) fix --dry-run --diff .; then \
		echo "Failed"; \
		exit 1; \
	fi; \
	echo "Success";
	@echo "------------------------------------------------------------"
	@echo "- Testing phpcs (failure)"
	@echo "------------------------------------------------------------"
	@if docker run --rm -v $(CURRENT_DIR)/tests/fail:/data $(IMAGE) fix --dry-run --diff .; then \
		echo "Failed"; \
		exit 1; \
	fi; \
	echo "Success";

tag:
	docker tag $(IMAGE) $(IMAGE):$(TAG)

pull:
	@grep -E '^\s*FROM' Dockerfile \
		| sed -e 's/^FROM//g' -e 's/[[:space:]]*as[[:space:]]*.*$$//g' \
		| xargs -n1 docker pull;

login:
	yes | docker login --username $(USER) --password $(PASS)

push:
	@$(MAKE) tag TAG=$(TAG)
	docker push $(IMAGE):$(TAG)

enter:
	docker run --rm --name $(subst /,-,$(IMAGE)) -it --entrypoint=/bin/sh $(ARG) $(IMAGE):$(TAG)
