# AGENTS.md — HEP Training

## Project Overview

HEP Training (TeSS) is a Rails 8 monolith that provides a catalogue for training Materials and Events.
Core stack: PostgreSQL, Apache Solr (Sunspot), Sidekiq, Redis, Sprockets + Yarn.

---

## 1. Execution Environment & Workflow

- Preferred workflow: Docker for CI and reproducible local testing. Native development is supported (see docs/install.md).

- Native setup (quick):
  - `bundle install`
  - `npm install -g yarn@1.22.22 && yarn install --frozen-lockfile`
  - `cp config/tess.example.yml config/tess.yml`
  - `cp config/secrets.example.yml config/secrets.yml`
  - `bundle exec rake db:create:all`
  - `bundle exec rake db:setup`
  - `bundle exec rails server`

- Docker / CI helpers:
  - Copy examples: `cp env.sample .env && cp config/tess.example.yml config/tess.yml && cp config/secrets.example.yml config/secrets.yml`
  - Build & run tests: `docker compose --profile test build test && docker compose --profile test run test`
  - Direct Docker test run: `docker compose run --remove-orphans test rails test`
  - Shortcut: `./make.sh test <path-to-test>` (wraps docker-compose test runner)

- Test commands (native):
  - Full suite: `bundle exec rails test`
  - Single test file: `bundle exec rails test test/path/to/file_test.rb`
  - Single test by line: `bundle exec rails test test/path/to/file_test.rb:LINE`

- Linting & audits:
  - Ruby linter: `bundle exec rubocop` (auto-fix: `rubocop -a`)
  - Gem audit: `bundle exec bundle-audit check --update`

- Assets & reindex:
  - `yarn install --frozen-lockfile`
  - `bundle exec rake assets:precompile`
  - Reindex Solr: `bundle exec rake tess:reindex`

Notes: CI workflows (`.github/workflows/*.yml`) show the authoritative commands used on GitHub Actions (DB/Redis services, node setup, bundler cache, test steps).

---

## 2. Ingestion Pipeline Rules

- Location & base class:
  - Ingestors live under `lib/ingestors/`.
  - Base class: `lib/ingestors/ingestor.rb` (Ingestors::Ingestor).

- Required interface:
  - Implement `self.config` (class-level) and `#read(url)` (instance-level); tests rely on these methods.

- Data flow:
  1. `ContentProvider` owns `Source` records; sources are configured for different feed types (e.g., `bioschemas`, `oai-pmh`, `github`, `material_csv`, `indico`, `cds_videos`).
  2. Automated ingestion is scheduled via `config/schedule.rb` and triggers `rake tess:automated_ingestion` (daily by default).

- Ingestion behavior constraints:
  - Ingestors should only create or update resources; they must not delete existing records.
  - New or updated resources must be associated with the Source's `ContentProvider`.
  - Respect administrative field-locking: do not overwrite fields that are locked by an admin/curator.

---

## 3. Search & Solr

- Search stack: Sunspot + Apache Solr; Solr schema/config at `solr/conf/` and per-environment settings in `config/sunspot.yml`.
- Tests run with Solr mocked/stubbed — a running Solr instance is not required for standard test execution.
- Reindex with: `bundle exec rake tess:reindex`

---

## 4. Testing & Code Quality

- Test framework: Minitest. System tests use Capybara + Selenium; CI uploads failure screenshots from `tmp/screenshots/`.
- HTTP stubs: WebMock + VCR; fixtures under `test/fixtures/files/`, VCR cassettes under `test/vcr_cassettes/`.
- Static checks: `rubocop`; security: `bundle-audit` and GitHub CodeQL run in CI.
- Database migration safety: `.github/workflows/migration-test.yml` validates migrations against a prior schema — keep migrations backward-compatible.
- PRs: Use the repository PR template `.github/pull_request_template.md` and include CI evidence when requested by the template.

---

## 5. Directory map (high level)

- app/controllers/, app/models/, app/views/, app/workers/
- lib/ingestors/ — ingestors and their base class
- lib/llm/ — helpers and prompts used by some ingestors
- config/schedule.rb — whenever cron definitions
- solr/conf/ — Solr config/schema
- test/, test/unit/, test/workers/, test/system/, test/fixtures/, test/vcr_cassettes/

---

## 6. Conventions & quick notes

- Config files must be copied from examples before DB or test operations (`config/*.example.yml`, `env.sample`). CI commonly uses `test/config/test_tess.yml`.
- File naming:
  - Ingestors: `*_ingestor.rb`; tests at `test/unit/ingestors/*_ingestor_test.rb`.
  - Workers: `*_worker.rb`; tests at `test/workers/*_worker_test.rb`.
- Tests:
  - Run with `bundle exec rails test` (native) or `docker compose run --remove-orphans test rails test` (dockerized).
- Fixtures & cassettes: keep VCR cassettes deterministic; CI relies on them for reproducible tests.
- CI: workflows of interest — `test.yml`, `docker-test.yml`, `docker-prod-test.yml`, `migration-test.yml`, `audit.yml`, `codeql-analysis.yml`.
