# Copilot instructions — TeSS

Purpose: quick reference for Copilot sessions to understand how to build, test, lint, and where to look for repo conventions.

---

## 1) Common build / test / lint commands

Environment setup (native):
- Install Ruby + Bundler, then: `bundle install`
- Install JS deps: `npm install -g yarn@1.22.22` then `yarn install --frozen-lockfile`
- Create config from examples (required before DB commands):
  - `cp config/tess.example.yml config/tess.yml`
  - `cp config/secrets.example.yml config/secrets.yml`
  - (CI uses `test/config/test_tess.yml` -> `config/tess.yml`)

Database & local setup:
- Create DBs: `bundle exec rake db:create:all`
- Setup DB + seed: `bundle exec rake db:setup`
- Prepare test DB: `bundle exec rake db:test:prepare`

Run app (dev):
- `bundle exec rails server`

Run tests:
- Full test suite: `bundle exec rails test`
- System tests: `bundle exec rails test:system`
- Run a single test file: `bundle exec rails test test/path/to/file_test.rb`
- Run a single test (by line): `bundle exec rails test test/path/to/file_test.rb:LINE`
- Alternative Docker/test helper: `docker compose --profile test build test` then `docker compose --profile test run test` or `docker compose run --remove-orphans test rails test`
- make.sh shortcut: `./make.sh test <path-to-test>` (wraps docker-compose test runner)

Linting / static checks:
- Ruby linter: `bundle exec rubocop` (auto-fix: `rubocop -a`)
- Gem audit (CI): `bundle exec bundle-audit check --update`

Assets / compile / reindex:
- JS install: `yarn install --frozen-lockfile`
- Precompile assets: `bundle exec rake assets:precompile`
- Reindex Solr: `bundle exec rake tess:reindex`

Background / cron:
- Run Sidekiq: `bundle exec sidekiq` (requires Redis)
- Deploy/update cron (whenever): `bundle exec whenever --update-crontab --set environment="<env>"`

Notes: CI workflows (.github/workflows/*.yml) show exact commands used on GitHub Actions (DB, Redis services, node setup, bundler cache).

---

## 2) High-level architecture (big picture)

- Rails monolith (Rails 8.x): app/ holds MVC (controllers, models, views). Views include JSON jbuilder templates used by the public API (app/views/**/*.jbuilder).
- Background processing: Sidekiq + app/workers/*.rb. Cron-like scheduling uses `whenever` (config/schedule.rb and config/schedule.yml).
- Ingestion pipeline: modular ingestors under `lib/ingestors/` (each ingestor class implements the ingestion interface; tests live in `test/unit/ingestors/`). A top-level rake task (`tess:automated_ingestion`) runs ingestion.
- Search: Apache Solr via Sunspot (solr/conf and `config/sunspot.yml`). Reindex with `bundle exec rake tess:reindex`.
- Persistence & caching: PostgreSQL (primary DB), Redis (Sidekiq, cache). CI uses service containers for postgres + redis.
- Frontend assets: managed via Sprockets + yarn (package.json). JS libs live in `app/assets/javascripts/` and vendor assets in `vendor/assets`.
- Docker: docker/ and docker-compose files provide local/test/production profiles. `make.sh` wraps common image build/push/test tasks.

---

## 3) Key conventions and repo-specific patterns

- Configuration files: copy example files before running the app/tests. Common examples:
  - `config/tess.example.yml` -> `config/tess.yml`
  - `config/secrets.example.yml` -> `config/secrets.yml`
  - CI uses `test/config/test_tess.yml` (see workflows)

- Ingestors: placed under `lib/ingestors/`. Naming convention: `<name>_ingestor.rb` with corresponding tests in `test/unit/ingestors/<name>_ingestor_test.rb`.

- Workers: Sidekiq workers live in `app/workers/` and follow `<name>_worker.rb`. Unit tests for workers are in `test/workers/`.

- Tests: Minitest (not RSpec). System/integration tests use Capybara + Selenium, and screenshots (tmp/screenshots) are uploaded by CI on failures.

- Assets: JS dependencies are installed with yarn; CI runs `yarn install` and `bundle exec rake assets:precompile` for deployment checks.

- Database migrations: migration tests are explicit in `.github/workflows/migration-test.yml` — CI checks applying migrations against previous schema. When changing DB schema, ensure migration tests pass.

- PRs and CI: There is a repository PR template `.github/pull_request_template.md`. When generating PR bodies or filling automated descriptions, preserve and use that template.

- Security/quality scans: Gem auditing (`bundle-audit`) and CodeQL run in CI. If adding a new language or compiled build step, update `.github/workflows` accordingly.

- Fixtures & VCR cassettes: test fixtures are under `test/fixtures/files/` and VCR cassettes under `test/vcr_cassettes/` — CI relies on these for deterministic tests.

---

## Where to look first (for Copilot suggestions)

- App logic: `app/controllers/`, `app/models/`, `app/workers/`.
- Ingestion: `lib/ingestors/` (and tests in `test/unit/ingestors/`).
- CI: `.github/workflows/*.yml` for the authoritative run commands.
- Configuration examples: `config/*.example.yml`, `test/config/test_tess.yml`.

---

If you want, add CI snippets, common test examples, or expand the single-test examples to include typical paths (e.g., `test/unit/ingestors/github_ingestor_test.rb`) — say which areas to expand.
