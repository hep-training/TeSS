# Makefile to build and push to a container registry and deploy using helm-chart
# usage :
# $ make <trainingstg|training|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>

BUILD			?=	trainingstg

GREEN			=	\033[0;32m
YELLOW			=	\033[1;33m
RED				=	\033[0;31m
NC				=	\033[0m

IMAGE			=	$(REGISTRY)/$(USERNAME)/$(REMOTE_REPO):$(BUILD)-$(TAG)

DOCKERFILE		=	Dockerfile
DOCKER_BUILD	=	docker build \
						--build-arg BUILD=$(BUILD) \
						--build-arg CR="True" \
						-t $(IMAGE) \
						--platform linux/amd64,linux/arm64 \
						-f $(DOCKERFILE) .
DOCKER_PUSH		=	docker push $(IMAGE)
DOCKER_COMPOSE	=	docker compose up -d --build --remove-orphans
CP				=	cp config/secrets/$(BUILD)/.env .env && \
					cp config/secrets/$(BUILD)/secrets.yml config/secrets.yml && \
					cp config/secrets/$(BUILD)/tess.yml config/tess.yml && \
					cp config/secrets/$(BUILD)/custom.en.yml config/locales/overrides/custom.en.yml
FIND			=	docker run --rm -it $(IMAGE) \
					find -L \( -path "./*tess*" -o -path "./*secrets*" -o -path "./*env*" \) | grep -iw ".env\|tess.yml\|secrets.yml"

_do:
ifndef REGISTRY
					@echo "$(RED)[MAKE] REGISTRY not set. Usage: make <trainingstg|training|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>$(NC)" ; false
endif
ifndef USERNAME
					@echo "$(RED)[MAKE] USERNAME not set. Usage: make <trainingstg|training|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>$(NC)" ; false
endif
ifndef REMOTE_REPO
					@echo "$(RED)[MAKE] REMOTE_REPO not set. Usage: make <trainingstg|training|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>$(NC)" ; false
endif
ifndef TAG
					@echo "$(RED)[MAKE] TAG not set. Usage: make <trainingstg|training|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>$(NC)" ; false
endif
					@$(MAKE) all REGISTRY=$(REGISTRY) USER=$(USER) REPO=$(REPO) TAG=$(TAG) BUILD=$(BUILD)


trainingstg:
					@$(MAKE) _do BUILD=trainingstg \
					REGISTRY=$(word 2,$(MAKECMDGOALS)) \
					USERNAME=$(word 3,$(MAKECMDGOALS)) \
					REMOTE_REPO=$(word 4,$(MAKECMDGOALS)) \
					TAG=$(word 5,$(MAKECMDGOALS))

training:
					@$(MAKE) _do BUILD=training \
					REGISTRY=$(word 2,$(MAKECMDGOALS)) \
					USERNAME=$(word 3,$(MAKECMDGOALS)) \
					REMOTE_REPO=$(word 4,$(MAKECMDGOALS)) \
					TAG=$(word 5,$(MAKECMDGOALS))

eversetraining:
					@$(MAKE) _do BUILD=eversetraining \
					REGISTRY=$(word 2,$(MAKECMDGOALS)) \
					USERNAME=$(word 3,$(MAKECMDGOALS)) \
					REMOTE_REPO=$(word 4,$(MAKECMDGOALS)) \
					TAG=$(word 5,$(MAKECMDGOALS))

build:
					@echo "$(YELLOW)[MAKE] Copying $(IMAGE)...$(NC)"
					$(COPY)
					@echo "$(YELLOW)[MAKE] Building $(IMAGE)...$(NC)"
					$(DOCKER_BUILD)	
					@echo "$(GREEN)[MAKE] DONE build...$(NC)"

push:
					@echo "$(YELLOW)[MAKE] Pushing $(IMAGE)...$(NC)"
					$(DOCKER_PUSH)	
					@echo "$(GREEN)[MAKE] DONE push...$(NC)"

test:
					@echo "$(YELLOW)[MAKE] Testing $(IMAGE)...$(NC)"
					$(FIND)	
					@echo "$(GREEN)[MAKE] DONE testing...$(NC)"


# DEV training

local:
					$(eval BUILD := $(word 2, $(MAKECMDGOALS)))
					@echo "$(YELLOW)[MAKE] BUILD=$(BUILD) - copying config$(NC)"
					$(CP)
					cp env.sample .env
					@echo "$(GREEN)[MAKE] Copied config$(NC)"
					docker compose run app bundle install
					docker compose run app bundle exec rake db:setup
					@echo "$(GREEN)[MAKE] Ready to build$(NC)"
					$(DOCKER_COMPOSE)

# change texte uniquement, pas colors
re: 
					docker compose restart app

# change pas grand chose (pas assets color ni color ni scss) - reessaye
clean:
					docker compose run app rm -rf tmp/cache
					docker compose run app rm -f tmp/pids/server.pid
					docker compose run app bundle exec rails tmp:clear
					docker compose run app rm -rf public/assets
					docker compose down -v --remove-orphans
					docker system prune -af
					@echo "$(GREEN)[MAKE] Ready to restart fresh!$(NC)"

# deploy:
# 	helm upgrade --install tess-$(BUILD) ./charts/tess \
# 		--values config/$(BUILD)/tess.yml \
# 		--set-file secrets=config/$(BUILD)/secrets.yml \
# 		--set-file env=config/$(BUILD)/.env

all:				build push test

.PHONY: 			all _do trainingstg training eversetraining build push test local localre clean

# Ignore positional arguments interpreted as targets
%:
	@: