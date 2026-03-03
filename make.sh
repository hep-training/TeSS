#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# make.sh — Build, push, and deploy TeSS
# Usage:
#   ./make.sh <trainingstg|heptraining|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>
#   ./make.sh local <trainingstg|heptraining|eversetraining>
#   ./make.sh clean
#   ./make.sh re
# ------------------------------------------------------------------------------

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

usage() {
  echo -e "${RED}[MAKE] Usage:${NC}"
  echo "  ./make.sh <trainingstg|heptraining|eversetraining> <REGISTRY> <USERNAME> <REMOTE_REPO> <TAG>"
  echo "  ./make.sh local <trainingstg|heptraining|eversetraining>"
  echo "  ./make.sh test <pathtotest>"
  echo "  ./make.sh clean"
  echo "  ./make.sh re"
  exit 1
}

check_required() {
  if [[ -z "${REGISTRY:-}" || -z "${USERNAME:-}" || -z "${REMOTE_REPO:-}" || -z "${TAG:-}" ]]; then
    usage
  fi
}

copy_secrets() {
  echo -e "${YELLOW}[MAKE] Copying config for ${BUILD}...${NC}"
  cp "config/secrets/${BUILD}/.env" .env
  cp "config/secrets/${BUILD}/secrets.yml" config/secrets.yml
  cp "config/secrets/${BUILD}/tess.yml" config/tess.yml
  cp "config/secrets/${BUILD}/custom.en.yml" config/locales/overrides/custom.en.yml 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Core tasks
# ------------------------------------------------------------------------------

condition() {
  while true; do
    echo -e "${YELLOW}CHECKLIST:\n \
      Did you build locally the right version of TeSS?\n \
      Did you change 'INSTANCE_VERSION' in .env ?\n \
      Do you have the right tess.yml config?\n \
      [y/n]${NC}"
    read -p "" yn
    case $yn in
      [Yy]* ) echo -e "${YELLOW}[MAKE] Confirmed.${NC}"; break ;;
      [Nn]* ) echo -e "${RED}[MAKE] Aborting.${NC}"; exit 1 ;;
      * ) echo "Please answer yes or no." ;;
    esac
  done
}

build() {
  echo -e "${YELLOW}[MAKE] Building ${IMAGE}...${NC}"
  copy_secrets
  docker build \
    --build-arg BUILD="${BUILD}" \
    --build-arg CR="True" \
    -t "${IMAGE}" \
    --platform linux/amd64,linux/arm64 \
    -f "${DOCKERFILE}" .
  echo -e "${GREEN}[MAKE] DONE build...${NC}"
}

push() {
  echo -e "${YELLOW}[MAKE] Pushing ${IMAGE}...${NC}"
  docker push "${IMAGE}"
  echo -e "${GREEN}[MAKE] DONE push...${NC}"
}

test_image() {
  echo -e "${YELLOW}[MAKE] Testing ${IMAGE}...${NC}"
  docker run --rm -it "${IMAGE}" \
    find -L \( -path "./*tess*" -o -path "./*secrets*" -o -path "./*env*" \) \
    | grep -iw ".env\|tess.yml\|secrets.yml"
  echo -e "${GREEN}[MAKE] DONE testing...${NC}"
}

local_env() {
  local BUILD="$1"
  copy_secrets
  cp env.sample .env
  echo -e "${GREEN}[MAKE] Copied config${NC}"

  docker compose run --remove-orphans app bundle install
  docker compose run --remove-orphans app bundle exec rake db:setup
  echo -e "${GREEN}[MAKE] Ready to build${NC}"
  docker compose up -d --build
}

test() {
  if [ -z "$1" ]; then
    docker compose run --remove-orphans test rails test
  else
    docker compose run --remove-orphans test rails test $1
  fi
}

restart_app() {
  echo -e "${YELLOW}[MAKE] Restarting app...${NC}"
  docker compose restart app
}

clean_env() {
  echo -e "${YELLOW}[MAKE] Cleaning environment...${NC}"
  docker compose run app rm -rf tmp/cache
  docker compose run app rm -f tmp/pids/server.pid
  docker compose run app bundle exec rails tmp:clear
  docker compose run app rm -rf public/assets
  docker compose down -v --remove-orphans
  docker system prune -af
  echo -e "${GREEN}[MAKE] Ready to restart fresh!${NC}"
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------

main() {
  local CMD="${1:-}"
  shift || true

  case "$CMD" in
    trainingstg|heptraining|eversetraining)
      BUILD="$CMD"
      REGISTRY="${1:-}"
      USERNAME="${2:-}"
      REMOTE_REPO="${3:-}"
      TAG="${4:-}"
      check_required
      IMAGE="${REGISTRY}/${USERNAME}/${REMOTE_REPO}:${BUILD}-${TAG}"
      DOCKERFILE="Dockerfile"
      condition
      build
      push
      test_image
      ;;

    local)
      local_env "${1:-}"
      ;;

    test)
      test "${1:-}"
      ;;

    clean)
      clean_env
      ;;

    re)
      restart_app
      ;;

    *)
      usage
      ;;
  esac
}

main "$@"
