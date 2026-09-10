# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [3.0.34] - 2026-09-09

- TAG: [v3.0.34][3.0.34t]
- COVERAGE: 91.95% -- 6101/6635 lines in 47 files
- BRANCH COVERAGE: 76.43% -- 2332/3051 branches in 47 files
- 50.23% documented

### Fixed

- Detect and reset release lockfiles whose BUNDLED WITH version lacks a matching Bundler checksum.

- Declare the intentional version_gem runtime-heads dependency overlap for templating self-tests.

## [3.0.33] - 2026-09-07

- TAG: [v3.0.33][3.0.33t]
- COVERAGE: 91.76% -- 6068/6613 lines in 47 files
- BRANCH COVERAGE: 76.11% -- 2310/3035 branches in 47 files
- 50.35% documented

### Fixed

- Isolate the published-gem availability probe from locally activated gems so release validation resolves the registry dependency graph.

## [3.0.32] - 2026-09-07

- TAG: [v3.0.32][3.0.32t]
- COVERAGE: 91.83% -- 6067/6607 lines in 47 files
- BRANCH COVERAGE: 76.38% -- 2318/3035 branches in 47 files
- 50.35% documented

### Fixed

- Preserve active local dependency selectors while generating Appraisal files during family templating.

## [3.0.31] - 2026-09-06

- TAG: [v3.0.31][3.0.31t]
- COVERAGE: 91.85% -- 6060/6598 lines in 47 files
- BRANCH COVERAGE: 76.33% -- 2315/3033 branches in 47 files
- 50.00% documented

### Fixed

- Preserve every configured Bundler lockfile platform when resetting release lockfiles.

- Materialize normalized release bundles before running bundle-exec release checks.

## [3.0.30] - 2026-09-01

- TAG: [v3.0.30][3.0.30t]
- COVERAGE: 91.68% -- 6038/6586 lines in 47 files
- BRANCH COVERAGE: 76.31% -- 2310/3027 branches in 47 files
- 50.00% documented

### Fixed

- Add an isolated family-member publish mode for concurrent monorepo releases.

- Add serialized family-member checksum finalization for concurrent monorepo releases.

## [3.0.29] - 2026-09-01

- TAG: [v3.0.29][3.0.29t]
- COVERAGE: 91.58% -- 6003/6555 lines in 47 files
- BRANCH COVERAGE: 76.25% -- 2302/3019 branches in 47 files
- 50.24% documented

### Fixed

- Install bootstrap gems required by statically evaluated Gemfiles before isolated release lockfile resolution.

- Ignore inactive nested Gemfile bootstrap requirements when their appraisal lockfile does not include the bootstrap gem.

## [3.0.28] - 2026-09-01

- TAG: [v3.0.28][3.0.28t]
- COVERAGE: 91.50% -- 5986/6542 lines in 47 files
- BRANCH COVERAGE: 75.94% -- 2288/3013 branches in 47 files
- 50.24% documented

### Fixed

- Recognize disabled checksum validation as inert in unbundled command environments.

## [3.0.27] - 2026-08-31

- TAG: [v3.0.27][3.0.27t]
- COVERAGE: 91.68% -- 5998/6542 lines in 47 files
- BRANCH COVERAGE: 76.20% -- 2296/3013 branches in 47 files
- 50.24% documented

### Added

- Emit GitHub Release creation and asset-upload lifecycle events, including retry attempts.

### Fixed

- Retry transient GitHub Release asset uploads and report every failed asset.

## [3.0.26] - 2026-08-31

- TAG: [v3.0.26][3.0.26t]
- COVERAGE: 91.60% -- 5967/6514 lines in 47 files
- BRANCH COVERAGE: 76.17% -- 2286/3001 branches in 47 files
- 50.47% documented

### Fixed

- Refresh existing GitHub Release notes while backfilling missing assets.

## [3.0.25] - 2026-08-31

- TAG: [v3.0.25][3.0.25t]
- COVERAGE: 91.30% -- 5949/6516 lines in 47 files
- BRANCH COVERAGE: 76.09% -- 2282/2999 branches in 47 files
- 50.47% documented

### Fixed

- Attach missing assets when recovering an existing GitHub Release.

## [3.0.24] - 2026-08-31

- TAG: [v3.0.24][3.0.24t]
- COVERAGE: 91.38% -- 5934/6494 lines in 47 files
- BRANCH COVERAGE: 75.98% -- 2271/2989 branches in 47 files
- 50.47% documented

### Fixed

- Keep Gemfile bootstrap dependencies available while resetting explicitly allowed monorepo release lockfiles.

- Keep installed Gemfile bootstrap dependencies available for every release lockfile reset.

- Emit explicit logical release resume-step metadata instead of relying on command-event ordering.

## [3.0.23] - 2026-08-30

- TAG: [v3.0.23][3.0.23t]
- COVERAGE: 91.35% -- 5881/6438 lines in 47 files
- BRANCH COVERAGE: 76.01% -- 2250/2960 branches in 47 files
- 50.47% documented

### Fixed

- Add an explicit reset option for release graphs that must omit the optional changelog dependency.

## [3.0.22] - 2026-08-30

- TAG: [v3.0.22][3.0.22t]
- COVERAGE: 91.58% -- 5893/6435 lines in 47 files
- BRANCH COVERAGE: 76.32% -- 2259/2960 branches in 47 files
- 50.47% documented

### Changed

- Add an appraisal-only release skip while preserving documentation generation.

## [3.0.21] - 2026-08-30

- TAG: [v3.0.21][3.0.21t]
- COVERAGE: 91.66% -- 5894/6430 lines in 47 files
- BRANCH COVERAGE: 76.40% -- 2260/2958 branches in 47 files
- 50.47% documented

### Changed

- Mark coordinated family release-preparation commits so CI can distinguish aggregate validation from duplicate member release commits.

## [3.0.20] - 2026-08-30

- TAG: [v3.0.20][3.0.20t]
- COVERAGE: 91.44% -- 5875/6425 lines in 47 files
- BRANCH COVERAGE: 76.07% -- 2248/2955 branches in 47 files
- 50.47% documented

### Fixed

- Preserve configured monorepo member-path lockfiles during release while rejecting unapproved local paths.

## [3.0.19] - 2026-08-30

- TAG: [v3.0.19][3.0.19t]
- COVERAGE: 91.50% -- 5855/6399 lines in 47 files
- BRANCH COVERAGE: 76.21% -- 2249/2951 branches in 47 files
- 50.97% documented

### Fixed

- Run changelog coverage with the disposable release lockfile so host platform reconciliation cannot dirty a release.

- Normalize release lockfiles before changelog coverage runs.

- Isolate changelog coverage with the selected coverage Gemfile lockfile during release.

## [3.0.18] - 2026-08-30

- TAG: [v3.0.18][3.0.18t]
- COVERAGE: 91.58% -- 5852/6390 lines in 47 files
- BRANCH COVERAGE: 76.21% -- 2243/2943 branches in 47 files
- 50.97% documented

### Fixed

- Skip volatile contrib.rocks contributor images during pre-release Markdown image validation.

- Prevent temporary Git fixture maintenance from racing with parallel test cleanup.

- Ensure release Git hooks receive nil-valued environment overrides as unset variables on JRuby.

- Prevent temporary Git fixture cleanup from racing with Git auto-maintenance on older Ruby CI.

## [3.0.17] - 2026-08-29

- TAG: [v3.0.17][3.0.17t]
- COVERAGE: 91.48% -- 5839/6383 lines in 47 files
- BRANCH COVERAGE: 76.16% -- 2240/2941 branches in 47 files
- 50.97% documented

### Fixed

- Stage Bundler update lockfiles correctly when releasing a monorepo subgem.

- Bound RubyGems version lookups so release reconciliation cannot wait indefinitely on a live registry request.

- Keep release child commands and commit hooks on the canonical registry-backed lockfile environment.

## [3.0.16] - 2026-08-28

- TAG: [v3.0.16][3.0.16t]
- COVERAGE: 91.20% -- 5807/6367 lines in 47 files
- BRANCH COVERAGE: 75.93% -- 2227/2933 branches in 47 files
- 51.10% documented

### Fixed

- Retry release lockfile resets while newly published workspace gems propagate to the configured source.

## [3.0.15] - 2026-08-28

- TAG: [v3.0.15][3.0.15t]
- COVERAGE: 91.24% -- 5804/6361 lines in 47 files
- BRANCH COVERAGE: 76.00% -- 2226/2929 branches in 47 files
- 51.10% documented

### Fixed

- Correct Markdown reference validation after indented fenced code blocks in list items.

## [3.0.14] - 2026-08-28

- TAG: [v3.0.14][3.0.14t]
- COVERAGE: 91.46% -- 5818/6361 lines in 47 files
- BRANCH COVERAGE: 76.14% -- 2230/2929 branches in 47 files
- 50.86% documented

### Changed

- [kc] kettle-jem/prepare: updated 9 project files:
  - configuration (1)
  - dependencies (8)

- [kc] kettle-jem/template: updated 14 project files:
  - code and tests (2)
  - configuration (1)
  - dependencies (1)
  - documentation (1)
  - other (1)
  - workflows (8)

### Fixed

- Teach kettle-bump to update literal fallback versions in conditional gemspec loaders.

- Release lockfile resets now update the locked Bundler version before the release preparation commit, preventing the release's own Bundler upgrade from dirtying the working tree during publication.

- Standalone releases now commit Bundler lockfile updates separately before release preparation.

## [3.0.13] - 2026-08-25

- TAG: [v3.0.13][3.0.13t]
- COVERAGE: 91.54% -- 5758/6290 lines in 47 files
- BRANCH COVERAGE: 76.44% -- 2210/2891 branches in 47 files
- 50.74% documented

### Changed

- Add named standalone release aliases for CI bypass and numbered-step recovery.

## [3.0.12] - 2026-08-25

- TAG: [v3.0.12][3.0.12t]
- COVERAGE: 91.48% -- 5754/6290 lines in 47 files
- BRANCH COVERAGE: 76.34% -- 2207/2891 branches in 47 files
- 50.74% documented

### Changed

- Expose shared lockfile section inspection primitives for family release validation.

### Fixed

- Skip unresolved Kettle-Jem template image URLs during pre-release validation.

## [3.0.11] - 2026-08-24

- TAG: [v3.0.11][3.0.11t]
- COVERAGE: 91.27% -- 5699/6244 lines in 47 files
- BRANCH COVERAGE: 76.11% -- 2176/2859 branches in 47 files
- 51.11% documented

### Fixed

- Run release changelog coverage against the registry-backed dependency graph instead of inheriting local templating paths.

- Reset dynamic Bundler parent markers before switching a child process to another Gemfile, so release changelog coverage runs the target project specs.

## [3.0.10] - 2026-08-23

- TAG: [v3.0.10][3.0.10t]
- COVERAGE: 91.15% -- 5688/6240 lines in 47 files
- BRANCH COVERAGE: 76.13% -- 2175/2857 branches in 47 files
- 50.62% documented

### Fixed

- Omit the standalone kettle-changelog dependency from normal release-time Bundler resolution, preventing unpublished downstream gem cycles in monorepo release waves.

- Use a dependency-specific environment switch when omitting kettle-changelog from release Bundler resolution.

## [3.0.9] - 2026-08-23

- TAG: [v3.0.9][3.0.9t]
- COVERAGE: 91.36% -- 5698/6237 lines in 47 files
- BRANCH COVERAGE: 76.08% -- 2172/2855 branches in 47 files
- 50.62% documented

### Fixed

- Keep Bundler platform reconciliation in an isolated lockfile during release builds and publication so normalized release lockfiles remain clean.

## [3.0.8] - 2026-08-23

- TAG: [v3.0.8][3.0.8t]
- COVERAGE: 91.36% -- 5679/6216 lines in 47 files
- BRANCH COVERAGE: 76.24% -- 2169/2845 branches in 47 files
- 50.62% documented

### Fixed

- Release lockfile normalization now resolves in isolated gem paths, preventing unreleased locally installed versions from entering release lockfiles.

## [3.0.7] - 2026-08-15

- TAG: [v3.0.7][3.0.7t]
- COVERAGE: 91.41% -- 5674/6207 lines in 47 files
- BRANCH COVERAGE: 76.29% -- 2169/2843 branches in 47 files
- 50.62% documented

### Fixed

- Ignore Ruby-style bracket expressions when validating Markdown reference links.

- Poll all unfinished GitHub Actions workflows each cycle so late-dispatched workflows cannot be missed by the global CI startup timeout.

## [3.0.6] - 2026-08-11

- TAG: [v3.0.6][3.0.6t]
- COVERAGE: 91.47% -- 5670/6199 lines in 47 files
- BRANCH COVERAGE: 76.17% -- 2161/2837 branches in 47 files
- 50.62% documented

### Added

- Add --skip-changelog to release without skipping pre-release gates or the default task.

### Fixed

- Retry RubyGems publication outside the parent Bundler environment after an expired-edge OTP, with a short delay for TOTP refresh.

- Make --skip-changelog releases omit the unpublished standalone kettle-changelog dependency during lockfile normalization.

## [3.0.5] - 2026-08-10

- TAG: [v3.0.5][3.0.5t]
- COVERAGE: 91.65% -- 5663/6179 lines in 47 files
- BRANCH COVERAGE: 76.30% -- 2157/2827 branches in 47 files
- 50.74% documented

### Fixed

- Keep release lockfile platforms stable across repeated normalization passes.

## [3.0.4] - 2026-08-10

- TAG: [v3.0.4][3.0.4t]
- COVERAGE: 91.65% -- 5653/6168 lines in 47 files
- BRANCH COVERAGE: 76.13% -- 2146/2819 branches in 47 files
- 50.87% documented

### Fixed

- Honor K_RELEASE_CI_CONTINUE during GitHub Actions and GitLab release monitoring, continuing after failed checks instead of aborting.

## [3.0.3] - 2026-08-10

- TAG: [v3.0.3][3.0.3t]
- COVERAGE: 91.36% -- 5617/6148 lines in 47 files
- BRANCH COVERAGE: 75.85% -- 2120/2795 branches in 47 files
- 51.00% documented

### Fixed

- Skip volatile Star History chart image URLs during pre-release validation.

## [3.0.2] - 2026-08-10

- TAG: [v3.0.2][3.0.2t]
- COVERAGE: 91.56% -- 5629/6148 lines in 47 files
- BRANCH COVERAGE: 76.14% -- 2128/2795 branches in 47 files
- 51.00% documented

### Fixed

- Stop polling 1Password during release monitoring and support family-owned release secret brokers.

- Allow pre-release GitHub Actions pin validation to use the explicitly requested persistent cache when live TLS access is unavailable.

- Detect locally installed unreleased workspace gems through an unbundled RubyGems probe during release lockfile normalization.

- Isolate standalone kettle-changelog coverage and tests from family release orchestration environment.

## [3.0.1] - 2026-08-10

- TAG: [v3.0.1][3.0.1t]
- COVERAGE: 91.87% -- 5602/6098 lines in 47 files
- BRANCH COVERAGE: 76.29% -- 2117/2775 branches in 47 files
- 50.64% documented

### Fixed

- Run 1Password authorization keepalives through the interactive terminal so release prompts remain visible.

- Re-normalize release lockfiles after release tasks before commit and CI validation.

## [3.0.0] - 2026-08-09

- TAG: [v3.0.0][3.0.0t]
- COVERAGE: 91.48% -- 5552/6069 lines in 47 files
- BRANCH COVERAGE: 76.26% -- 2107/2763 branches in 47 files
- 50.77% documented

### Changed

- Move the kettle-changelog executable to the standalone kettle-changelog gem while retaining kettle-dev support APIs for the transition.

- Resolve standalone kettle-changelog through the generated Ruby-4-only modular release-tool Gemfile, with local path wiring for development.

### Fixed

- Use a dedicated standalone changelog bundle during bootstrap releases when the project bundle does not include kettle-changelog.

- Keep standalone changelog bootstrap paths out of target release tests and documentation.

## [2.5.28] - 2026-08-09

- TAG: [v2.5.28][2.5.28t]
- COVERAGE: 91.71% -- 5544/6045 lines in 47 files
- BRANCH COVERAGE: 76.48% -- 2104/2751 branches in 47 files
- 50.77% documented

### Fixed

- Retry an existing gem publication once with a fresh RubyGems MFA OTP when the release task reports an invalid OTP.

## [2.5.27] - 2026-08-09

- TAG: [v2.5.27][2.5.27t]
- COVERAGE: 91.77% -- 5530/6026 lines in 47 files
- BRANCH COVERAGE: 76.28% -- 2094/2745 branches in 47 files
- 50.90% documented

### Fixed

- Skip duplicate specs and coverage during release default checks while preserving local lint autocorrection

## [2.5.26] - 2026-08-08

- TAG: [v2.5.26][2.5.26t]
- COVERAGE: 91.64% -- 5522/6026 lines in 47 files
- BRANCH COVERAGE: 76.03% -- 2087/2745 branches in 47 files
- 50.90% documented

### Fixed

- Support family-level gem names and changelog paths when creating aggregate GitHub releases.

- Treat never-published RubyGems packages as having no release history.

- Keep local development paths disabled through release setup so release lockfiles remain registry-resolvable.

- Preserve kettle-jem template tokens during Markdown image URL normalization.

- Reset inherited Bundler file selection before running project release tasks.

- Run every project-local release check with the release lockfile environment, including prefixed rake commands, so local workspace paths cannot leak back into release lockfiles.

- Run gem build and publish commands with local workspace dependency switches disabled so release guards see the registry-backed lockfile.

- Recognize release commands with environment prefixes so configured secret providers can answer signing and RubyGems MFA prompts.

## [2.5.25] - 2026-08-07

- TAG: [v2.5.25][2.5.25t]
- COVERAGE: 91.48% -- 5465/5974 lines in 47 files
- BRANCH COVERAGE: 75.95% -- 2059/2711 branches in 47 files
- 50.90% documented

### Fixed

- Select the most recent GitHub Actions build when multiple runs exist for the same commit.

## [2.5.24] - 2026-08-07

- TAG: [v2.5.24][2.5.24t]
- COVERAGE: 91.79% -- 5480/5970 lines in 47 files
- BRANCH COVERAGE: 76.12% -- 2065/2713 branches in 47 files
- 50.90% documented

### Added

- GitHub releases can include published gem and checksum artifacts.

### Fixed

- Allow family orchestration to suppress per-member GitHub releases for monorepo release trains.

- Preserve successful GitHub release creation when the API response has no asset payload.

## [2.5.23] - 2026-08-07

- TAG: [v2.5.23][2.5.23t]
- COVERAGE: 91.93% -- 5467/5947 lines in 47 files
- BRANCH COVERAGE: 76.21% -- 2060/2703 branches in 47 files
- 50.90% documented

### Fixed

- Exclude Markdown test fixtures from release image and reference validation.

## [2.5.22] - 2026-08-07

- TAG: [v2.5.22][2.5.22t]
- COVERAGE: 91.88% -- 5464/5947 lines in 47 files
- BRANCH COVERAGE: 76.10% -- 2057/2703 branches in 47 files
- 50.90% documented

### Fixed

- CI monitoring can use an explicit repository root for monorepo release workflows.

## [2.5.21] - 2026-08-07

- TAG: [v2.5.21][2.5.21t]
- COVERAGE: 91.99% -- 5469/5945 lines in 47 files
- BRANCH COVERAGE: 76.14% -- 2058/2703 branches in 47 files
- 50.77% documented

### Fixed

- Release coverage now honors a project that disables hard coverage thresholds.

- Release-state version lookups now refresh when the cached RubyGems data predates the requested version.

## [2.5.20] - 2026-08-07

- TAG: [v2.5.20][2.5.20t]
- COVERAGE: 91.75% -- 5440/5929 lines in 47 files
- BRANCH COVERAGE: 76.14% -- 2049/2691 branches in 47 files
- 50.77% documented

### Fixed

- Prefer non-cancelled exact-commit GitHub Actions runs when workflow concurrency creates duplicate runs.

- Skip YARD lint when a project has no .yard-lint.yml policy.

## [2.5.19] - 2026-08-06

- TAG: [v2.5.19][2.5.19t]
- COVERAGE: 91.34% -- 5431/5946 lines in 47 files
- BRANCH COVERAGE: 75.28% -- 2037/2706 branches in 47 files
- 50.64% documented

### Changed

- Track the released kettle-gha-pins client and its cache/tag-resolution contract in the development lockfile and specs.

### Fixed

- Add release validation for Markdown reference labels and local heading anchors.

- Restore the Discord badge reference in CONTRIBUTING.md.

## [2.5.18] - 2026-08-03

- TAG: [v2.5.18][2.5.18t]
- COVERAGE: 91.45% -- 5293/5788 lines in 46 files
- BRANCH COVERAGE: 75.74% -- 2004/2646 branches in 46 files
- 50.41% documented

### Fixed

- Repair release lockfile recovery when locally installed workspace gems are retained as unreleased registry versions.

## [2.5.17] - 2026-08-02

- TAG: [v2.5.17][2.5.17t]
- COVERAGE: 91.45% -- 5292/5787 lines in 46 files
- BRANCH COVERAGE: 75.66% -- 2002/2646 branches in 46 files
- 50.41% documented

### Fixed

- kettle-jem-template-20260802-001 - Devcontainer JSON files now merge as JSONC,
  preserving comments and trailing commas during template updates.

## [2.5.16] - 2026-08-01

- TAG: [v2.5.16][2.5.16t]
- COVERAGE: 91.43% -- 5291/5787 lines in 46 files
- BRANCH COVERAGE: 75.66% -- 2002/2646 branches in 46 files
- 50.41% documented

### Changed

- kettle-jem-template-20260801-001 - Generated README gem dashboard links now
  use ClickGems instead of BestGems.

### Fixed

- Pre-release image validation now permits a current-repository workflow badge when its workflow exists locally and awaits the release push.

- Release changelog coverage runs now enforce the checked-in coverage workflow line and branch thresholds before pushing.

- kettle-jem-template-20260801-002 - Generated RSpec helpers now normalize
  managed configuration block bindings structurally, preventing mixed block
  parameter names from producing invalid configuration after a merge.
- kettle-jem-template-20260801-003 - Generated project metadata and
  documentation now normalize configured underscore hostnames to valid
  hyphenated hostnames.
- kettle-jem-template-20260801-004 - Generated organization README logos now
  use GitHub's stable organization avatar endpoint instead of assuming a
  matching Galtzo-hosted asset exists.

- Mark modern changelog coverage-threshold tooling specs pending on legacy Ruby Appraisals.

## [2.5.15] - 2026-08-01

- TAG: [v2.5.15][2.5.15t]
- COVERAGE: 91.55% -- 5266/5752 lines in 46 files
- BRANCH COVERAGE: 75.74% -- 1986/2622 branches in 46 files
- 50.41% documented

### Added

- Add verified GitHub Release backfill checks and NDJSON support to kettle-gh-release.

- Add a changelog reformat mode for historical release metadata repair.

- Add historical changelog reformat and GitHub release reconciliation checks.

- Add an explicit historical release-section backfill mode for tagged releases.

- Add kettle-gh-release update mode for existing GitHub Release notes.

### Fixed

- Allow the changelog entry writer to add to malformed Unreleased sections with duplicate headings.

- Honor K_CHANGELOG_PATH when adding an Unreleased changelog entry.

- Canonicalize legacy release headings and remove redundant historical placeholders during reformat.

- Roll back unpublished prepared changelog sections when version.rb returns to the published version.

## [2.5.14] - 2026-07-31

- TAG: [v2.5.14][2.5.14t]
- COVERAGE: 91.94% -- 5146/5597 lines in 46 files
- BRANCH COVERAGE: 76.13% -- 1946/2556 branches in 46 files
- 50.41% documented

### Fixed

- `kettle-reset release-lockfiles` now requires SHA-256 checksums only for
  registry-sourced gems, allowing valid Git-sourced dependencies such as the
  `simplecov` fork to remain checksumless.

## [2.5.13] - 2026-07-31

- TAG: [v2.5.13][2.5.13t]
- COVERAGE: 91.81% -- 5137/5595 lines in 46 files
- BRANCH COVERAGE: 76.06% -- 1944/2556 branches in 46 files
- 50.41% documented

### Fixed

- `kettle-release` now treats `origin` as the default required parity remote
  while allowing optional mirror remotes to be skipped after fetch retries,
  so a transient Codeberg/GitLab mirror outage does not block publishing.

### Added

- `kettle-release --events` now emits `remote_parity` events for remote parity
  fetch attempts, skipped optional remotes, required failures, and parity
  completion.
- `kettle-release --events` now emits `ci_monitor` events around CI monitoring
  start, per-workflow GitHub Actions progress, GitLab pipeline outcomes,
  success, and failure.
- `kettle-release --events` now emits `pre_release` events around
  `kettle-pre-release` checks and selected check summaries.
- `kettle-changelog --events` now emits `changelog` events around release plan,
  coverage generation, and changelog update activity, and `kettle-release
  --events` forwards those child events.
- `kettle-release --events` now emits `release_lockfile` and `release_probe`
  events for release lockfile reset/validation and published-gem availability
  probes.
- `kettle-dev` now requires `kettle-ndjson` 0.1.9 or newer so release event
  streams resolve against the protocol that includes remote parity and CI
  monitor, pre-release, changelog, release lockfile, and release probe events.

- `kettle-release --events` now emits GitHub CI wait/start/tick monitor events
  while waiting for workflow runs to appear and complete.

### Changed

- `kettle-release --events` now emits clearer `command_step` names and compact
  per-command summaries for common release commands instead of shell-derived
  labels such as `env__u`.

## [2.5.12] - 2026-07-31

- TAG: [v2.5.12][2.5.12t]
- COVERAGE: 91.73% -- 4961/5408 lines in 46 files
- BRANCH COVERAGE: 75.98% -- 1850/2435 branches in 46 files
- 50.68% documented

### Added

- `kettle-release-secrets-doctor` can probe 1Password release secret
  authorization across same-process, child-process, and threaded shapes.

- `kettle-release-secrets-doctor` now probes additional 1Password
  authorization boundaries, including parent-child, Bundler child, and
  Bundler-env-reset child process shapes.

- `kettle-release --events` now emits `secret_provider` events around release
  secret keepalives and provider-backed prompt responses.

### Fixed

- `kettle-release` now keeps configured release secrets providers warm during
  CI waits and alerts before provider lookups, reducing missed 1Password
  authorization prompts during long release runs.

- `kettle-release` keepalive alerts now include the elapsed release time so
  delayed 1Password prompts are easier to correlate with the run.

- `kettle-dev` now requires `kettle-ndjson` 0.1.4 or newer so
  `kettle-release --events=secret_provider` cannot resolve against an older
  event protocol.
- `kettle-release` lockfile reset now preserves existing bundle platforms and
  adds the current host platform, preventing release-prep lockfiles from losing
  Linux support during full rebuilds.
- `kettle-pre-release` Markdown image URL normalization now keeps encoded query
  values stable, avoiding release-time churn in shields URLs with nested URL
  parameters.
- `kettle-release` now runs `bin/setup` with inherited Bundler bootstrap
  variables unset, so a release lockfile reset can install newly selected gems
  before later release tasks run.

## [2.5.11] - 2026-07-30

- TAG: [v2.5.11][2.5.11t]
- COVERAGE: 91.66% -- 4756/5189 lines in 44 files
- BRANCH COVERAGE: 76.03% -- 1802/2370 branches in 44 files
- 53.78% documented

### Fixed

- RubyGems version lookups now share the 30-day local version-response cache
  used by dependency floor checks, so release-state and changelog generation can
  survive transient RubyGems API failures for untouched gems while still
  refreshing recently released gems.
- RubyGems release-state cache-bust markers now stay fresh for 30 days after
  `kettle-release` publishes a gem, so downstream tooling can selectively
  refresh recently released gems without refreshing untouched gems.

## [2.5.10] - 2026-07-30

- TAG: [v2.5.10][2.5.10t]
- COVERAGE: 92.12% -- 4737/5142 lines in 44 files
- BRANCH COVERAGE: 76.41% -- 1785/2336 branches in 44 files
- 54.41% documented

### Fixed

- `kettle-changelog` coverage generation now clears inherited Bundler
  environment before running the coverage-root bundle, avoiding member bundle
  leakage in shared monorepo release changelogs.
- `kettle-changelog` coverage generation now carries `PATH` into its cleaned
  subprocess environment so the selected coverage-root bundle executable can be
  resolved without inheriting Bundler state.

## [2.5.9] - 2026-07-30

- TAG: [v2.5.9][2.5.9t]
- COVERAGE: 91.91% -- 4726/5142 lines in 44 files
- BRANCH COVERAGE: 76.37% -- 1784/2336 branches in 44 files
- 54.41% documented

### Fixed

- `kettle-changelog` coverage generation now pins `BUNDLE_GEMFILE` to
  `K_CHANGELOG_COVERAGE_ROOT/Gemfile`, so shared monorepo release changelogs
  collect aggregate family coverage instead of reusing the member bundle.

## [2.5.8] - 2026-07-30

- TAG: [v2.5.8][2.5.8t]
- COVERAGE: 92.10% -- 4733/5139 lines in 44 files
- BRANCH COVERAGE: 76.48% -- 1785/2334 branches in 44 files
- 54.41% documented

### Changed

- `kettle-changelog` now accepts `K_CHANGELOG_COVERAGE_ROOT` so monorepo release
  flows can collect aggregate coverage from a family bundle without running the
  changelog command from the family root.

## [2.5.7] - 2026-07-30

- TAG: [v2.5.7][2.5.7t]
- COVERAGE: 91.74% -- 4710/5134 lines in 44 files
- BRANCH COVERAGE: 76.37% -- 1781/2332 branches in 44 files
- 54.41% documented

### Added

### Changed

- Raised the runtime dependency floors for `kettle-ndjson` to `0.1.3` and
  `kettle-rb` to `0.1.7`.
- `kettle-changelog` now accepts `K_CHANGELOG_PATH` so monorepo release flows
  can run inside a gem while updating a shared root changelog.

### Fixed

- kettle-jem-template-20260728-004 - Generated dep-heads workflows now use the
  setup-ruby Bundler install path for direct appraisal Gemfiles, avoiding rv
  lockfile parser failures on Git and path dependencies.
- kettle-jem-template-20260728-005 - VersionGem bootstrap now creates the
  missing canonical version spec when a project only has shim namespace version
  specs.
- kettle-jem-template-20260729-001 - Generated JRuby 9.4 workflows now use the
  legacy manual bundle install path, avoiding setup-time Bundler full-index
  failures against `gem.coop`.
- kettle-jem-template-20260729-002 - VersionGem bootstrap now preserves
  and templates dedicated `version_gem.rb` entrypoints even when the gemspec
  dependency is intentionally omitted, and generated anonymous-loader specs
  cover both `version.rb` and `version_gem.rb`.
- kettle-jem-template-20260730-001 - Gemspec package file enumeration now runs
  relative to the gemspec directory, so packaged template assets are included
  even when the gemspec is loaded from another working directory.

## [2.5.6] - 2026-07-28

- TAG: [v2.5.6][2.5.6t]
- COVERAGE: 91.93% -- 4716/5130 lines in 44 files
- BRANCH COVERAGE: 76.39% -- 1780/2330 branches in 44 files
- 54.41% documented

### Fixed

- Unexpected Bundler environment warnings emitted by unbundled release/reset
  subprocess setup are now de-duplicated per process.

## [2.5.5] - 2026-07-28

- TAG: [v2.5.5][2.5.5t]
- COVERAGE: 91.66% -- 4694/5121 lines in 44 files
- BRANCH COVERAGE: 76.18% -- 1772/2326 branches in 44 files
- 54.44% documented

### Fixed

- `kettle-release` and `kettle-reset release-lockfiles` now validate local
  workspace gem versions with an isolated Bundler inline probe against the
  configured gem source instead of RubyGems.org version APIs, and release task
  lockfile resets retry transient source propagation failures.

- kettle-jem-template-20260728-002 - Generated RuboCop configs now ignore the
  same `gemfiles/vendor/bundle` tree as `.gitignore`, so vendored dependency
  installs are not reported as project lint debt.
- kettle-jem-template-20260728-003 - Generated dep-heads workflows now run
  TruffleRuby jobs with current RubyGems and Bundler, avoiding setup failures
  before the test suite starts.

- `kettle-release` and `kettle-reset` now warn when unexpected `BUNDLE_*` or
  `BUNDLER_*` environment variables are present while preparing unbundled
  subprocesses.

## [2.5.4] - 2026-07-28

- TAG: [v2.5.4][2.5.4t]
- COVERAGE: 91.68% -- 4618/5037 lines in 42 files
- BRANCH COVERAGE: 76.54% -- 1768/2310 branches in 42 files
- 56.04% documented

### Changed

- Raised the runtime dependency floor for `kettle-gha-pins` to `0.3.3`.

## [2.5.3] - 2026-07-27

- TAG: [v2.5.3][2.5.3t]
- COVERAGE: 91.86% -- 4627/5037 lines in 42 files
- BRANCH COVERAGE: 76.58% -- 1769/2310 branches in 42 files
- 56.04% documented

### Fixed

- `kettle-release` now resets release lockfiles before release task bundle
  installs, preventing stale `Appraisal.root.gemfile.lock` entries for
  unreleased sibling gems from aborting appraisal generation.

## [2.5.2] - 2026-07-27

- TAG: [v2.5.2][2.5.2t]
- COVERAGE: 91.92% -- 4619/5025 lines in 42 files
- BRANCH COVERAGE: 76.50% -- 1761/2302 branches in 42 files
- 56.04% documented

### Fixed

- `kettle-reset release-lockfiles` now detects local workspace gem versions
  that Bundler locked as registry gems even when checksum entries are present,
  so unreleased sibling versions are not committed into release lockfiles.

- `kettle-reset` now scans workspace sibling directories with Ruby 2.4
  compatible APIs, fixing Ruby 2.4 CI failures in lockfile reset specs.

### Changed

- kettle-jem-template-20260728-001 - Generated Ruby workflows now use clearer
  setup-ruby-flash planning and can prepare appraisal-only jobs without
  installing the main Gemfile bundle.

## [2.5.1] - 2026-07-27

- TAG: [v2.5.1][2.5.1t]
- COVERAGE: 91.69% -- 4590/5006 lines in 42 files
- BRANCH COVERAGE: 76.20% -- 1748/2294 branches in 42 files
- 56.21% documented

### Fixed

- `kettle-release --secrets-provider 1password` now supports
  `KETTLE_RELEASE_1PASSWORD_CLI` for systems where the `op` executable is not
  available on PATH.

## [2.5.0] - 2026-07-26

- TAG: [v2.5.0][2.5.0t]
- COVERAGE: 91.71% -- 4589/5004 lines in 42 files
- BRANCH COVERAGE: 75.98% -- 1743/2294 branches in 42 files
- 56.21% documented

### Added

- `kettle-release` can now use `--secrets-provider 1password` to load the gem
  signing passphrase and RubyGems MFA OTP from the local 1Password CLI during
  direct release runs.
- `kettle-release` and `kettle-changelog` now accept `--yes` to approve their
  release confirmation prompts without interactive input.

- `kettle-reset Gemfile.lock` now resets CI-facing lockfiles by disabling local
  sibling path environments and updating path-sourced or checksum-gap gems back
  to released registry versions with checksums.
- `kettle-reset Appraisal.root.gemfile.lock` and
  `kettle-reset release-lockfiles` now cover the appraisal root lockfile used by
  release and appraisal generation.

- kettle-jem-template-20260727-001 - Spec harness documentation now lists the
  RSpec helpers provided by `kettle-test`.

### Changed

- Documented family release credential automation with 1Password and the
  unreleased-family-gem cleanup workflow.
- Shared release secret provider code now lives in `kettle-dev`, allowing
  `kettle-family` to cache the signing passphrase once while child
  `kettle-release` processes fetch RubyGems OTP values at prompt time.

- `kettle-release` now skips the default task's duplicate test and coverage run
  when `kettle-changelog` already generated strict coverage in the same release.
- `kettle-changelog` now requests JSON-only coverage output for release metadata
  generation, reducing formatter noise during release preparation.

### Fixed

- `kettle-release --secrets-provider 1password` now validates the gem signing
  passphrase before build/release and aborts instead of prompting if configured
  secrets are unavailable.

- Direct `kettle-release --secrets-provider 1password` runs now use the same
  PTY-backed prompt bridge as family releases, so PEM passphrase prompts receive
  the configured provider value instead of leaking through interactively.

- `kettle-release --secrets-provider 1password` now recognizes the real
  1Password provider as configured instead of misclassifying it as the
  interactive fallback provider.

- Release secrets provider lookup now honors `provider` from explicit config,
  and direct provider lookup failures raise `Kettle::Dev::Error`.

- kettle-jem-template-20260726-003 - Coverage upload steps now treat Coveralls,
  QLTY, and Codecov as optional, so provider outages do not fail CI when local
  coverage thresholds still pass.

- `kettle-release` now uses the same lockfile reset logic before release prep
  commits, and can reset and amend release lockfiles before the first push if
  local paths reappear mid-release.
- Release lockfile validation now allows the current gem's own `gemspec` path
  source while still rejecting local sibling path sources.
- Release version checks now use RubyGems.org directly, while post-publish
  availability probes continue to verify the gem.coop Bundler source.
- Release lockfile reset now uninstalls unreleased locally installed workspace
  gem versions before regenerating `Gemfile.lock` and
  `Appraisal.root.gemfile.lock`, preventing local-only versions from being
  written as registry gems with checksums.

- Release and changelog specs now route git commit, amend, tag, reset, and
  release-state queries through `GitAdapter`, so test runs do not invoke the
  caller's real git signing configuration.

- `kettle-release` no longer loads the extracted `cgi` gem while booting, so
  Ruby 2.4 appraisals can run release executable smoke tests without hitting
  newer `cgi` code that requires `String#delete_prefix`.
- `kettle-release` now reports the exact lockfile diagnostics that trigger its
  pre-push reset attempt, amends the release prep commit only when tracked
  lockfiles changed, and reports unrepaired diagnostics before aborting.
- Release lockfile validation no longer treats the current gem's own
  `remote: .` lockfile source as a local sibling path when line endings or
  whitespace differ.

- Release lockfile validation now uses `Bundler::LockfileParser` for source
  classification, so registry remotes such as `https://gem.coop/` are not
  mistaken for local path sources.

- Release lockfile fallback output now distinguishes between amending the release
  prep commit and restoring uncommitted lockfile drift back to that commit.

## [2.4.6] - 2026-07-26

- TAG: [v2.4.6][2.4.6t]
- COVERAGE: 92.57% -- 4135/4467 lines in 38 files
- BRANCH COVERAGE: 76.58% -- 1612/2105 branches in 38 files
- 59.47% documented

### Added

- kettle-jem-template-20260726-001 - Projects now include YARD lint
  configuration and documentation dependencies so documentation issues fail
  before generated docs are refreshed.

### Changed

- Executable startup headers are now shown only when `--verbose` is passed;
  `-v` and `--version` still print just the executable version and exit.
- `yard:lint` now runs `yard-lint --quiet` first and only reruns with full
  output when lint fails, keeping warning-only default and release output
  compact while preserving failure diagnostics.
- `yard:lint` now runs before `yard` and before the default task reaches YARD
  documentation generation, so documentation lint failures fail earlier in CI.

- kettle-jem-template-20260725-002 - Version specs now use `anonymous_loader` to
  cover `version.rb` without redefining constants, or are removed when version
  specs are not managed for the project.

### Fixed

- `yard.rake` specs now account for appraisal bundles without documentation
  dependencies, so current-appraisal CI does not expect `yard:lint` when YARD
  is unavailable.
- Executable version specs now ignore RubyGems platform redefinition warnings
  from appraisal bundles while still failing on real executable stderr.
- `kettle-release` lockfile normalization now passes `--add-checksums` when it
  repairs release lockfiles, so empty CHECKSUMS entries are not left behind for
  the pre-commit validation pass.
- `kettle-release` lockfile normalization now passes `BUNDLE_LOCKFILE`, so
  appraisal root lockfiles are repaired in place instead of accidentally
  rewriting `Gemfile.lock`.
- `kettle-dvcs` documentation examples no longer use Ruby-only YARD example
  tags for shell commands, so `yard:lint` can pass before docs are regenerated.
- `kettle-changelog` now reports `bin/rake yard` failures directly, including
  `yard:lint` output, instead of misreporting them as missing documentation
  percentages.

- kettle-jem-template-20260726-002 - Generated version files now document their
  version namespace and constants, reducing warning-only YARD lint output.

## [2.4.5] - 2026-07-25

- TAG: [v2.4.5][2.4.5t]
- COVERAGE: 92.40% -- 4096/4433 lines in 38 files
- BRANCH COVERAGE: 76.57% -- 1598/2087 branches in 38 files
- 59.16% documented

### Fixed

- `kettle-release` availability validation now uses Bundler's resolver and
  installer without activating the just-published gem or re-entering the
  caller's repository bundle.

## [2.4.4] - 2026-07-25

- TAG: [v2.4.4][2.4.4t]
- COVERAGE: 92.01% -- 4079/4433 lines in 38 files
- BRANCH COVERAGE: 76.04% -- 1587/2087 branches in 38 files
- 59.16% documented

### Fixed

- `kettle-release` availability validation now resolves the exact published gem
  from gem.coop without requiring it, so framework-dependent gems are not
  mistaken for unavailable releases after RubyGems accepts the push.
- `kettle-release` now records a candidate as published immediately after the
  push command succeeds, preventing post-publish validation failures from
  triggering unpublished-gem local cleanup.

- Legacy-engine GitHub Actions workflows now configure Bundler to mirror
  gem.coop to RubyGems.org during explicit CI installs, avoiding unsupported
  gem.coop full-index requests from old Bundler/RubyGems combinations.

## [2.4.3] - 2026-07-25

- TAG: [v2.4.3][2.4.3t]
- COVERAGE: 92.17% -- 4082/4429 lines in 38 files
- BRANCH COVERAGE: 76.38% -- 1594/2087 branches in 38 files
- 59.16% documented

### Added

- `kettle-release` now supports `--events[=TYPES]`, `--json`, and
  `--report PATH` machine-readable release reporting backed by the shared
  `kettle-ndjson` event toolkit.

### Changed

- kettle-jem-template-20260725-001 - Generated JRuby and TruffleRuby workflow
  files now run when pull request head branches start with `feature/release`,
  so release CI monitoring does not report intentionally skipped engine
  workflows as failures.

### Fixed

- `kettle-release` now retries transient git remote fetch failures during
  strict pre-push trunk parity checks, and failures now include an explicit
  `--skip-remotes` recovery hint for intentionally unavailable remotes.
- `kettle-release` now waits briefly and retries post-publish gem.coop
  availability validation before failing, so normal registry mirror lag does
  not abort immediately after a successful RubyGems push.

- Raised the `kettle-ndjson` runtime dependency floor to v0.1.1 so the
  dependency remains installable on kettle-dev's Ruby 2.4+ support floor.

## [2.4.2] - 2026-07-24

- TAG: [v2.4.2][2.4.2t]
- COVERAGE: 92.36% -- 3991/4321 lines in 38 files
- BRANCH COVERAGE: 76.06% -- 1563/2055 branches in 38 files
- 59.00% documented

### Fixed

- `kettle-release` now validates published gem availability with an isolated
  Bundler probe against gem.coop before continuing past the publish step, and
  uninstalls newly introduced local candidate gems when the release did not
  happen or cannot be validated.

## [2.4.1] - 2026-07-24

- TAG: [v2.4.1][2.4.1t]
- COVERAGE: 92.29% -- 3928/4256 lines in 38 files
- BRANCH COVERAGE: 76.09% -- 1550/2037 branches in 38 files
- 58.66% documented

### Fixed

- `kettle-release` now normalizes and revalidates release lockfiles after
  mutating setup/appraisal/doc steps, before committing or pushing, so local
  path remotes and locally installed registry gems with empty lockfile
  checksums cannot leak into CI.

## [2.4.0] - 2026-07-23

- TAG: [v2.4.0][2.4.0t]
- COVERAGE: 92.49% -- 3830/4141 lines in 38 files
- BRANCH COVERAGE: 76.22% -- 1516/1989 branches in 38 files
- 58.66% documented

### Added

- Packaged executables now answer `-v` and bare `--version` with the
  `kettle-dev` gem version they shipped with.

### Changed

- Raised the runtime dependency floor for `kettle-gha-pins` to `0.3.1`.
- Packaged executables now share a consistent startup header on normal
  execution paths.
- Markdown image URL cache/live/skipped progress now uses the same multi-line
  `tty-progressbar` output as GitHub Actions pin checks.

## [2.3.11] - 2026-07-23

- TAG: [v2.3.11][2.3.11t]
- COVERAGE: 92.17% -- 3791/4113 lines in 37 files
- BRANCH COVERAGE: 75.80% -- 1500/1979 branches in 37 files
- 59.51% documented

### Fixed

- GitHub Actions release monitoring now falls back to repository-level workflow
  runs when a per-workflow endpoint lags for the pushed HEAD, and waits up to
  five minutes by default for workflows to appear.

## [2.3.10] - 2026-07-23

- TAG: [v2.3.10][2.3.10t]
- COVERAGE: 92.35% -- 3790/4104 lines in 37 files
- BRANCH COVERAGE: 75.95% -- 1500/1975 branches in 37 files
- 60.00% documented

### Changed

- Local development tooling now uses `kettle-gha-pins` 0.2.0 or newer on
  Ruby 3.2+, while keeping older supported Ruby bundles solvable.
- `kettle-gha-sha-pins` now delegates GitHub Actions release-tag parsing,
  canonicalization, cache persistence, GitHub release/tag/commit resolution,
  and upgrade-target selection to the shared
  `kettle-gha-pins` gem.
- `kettle-gha-sha-pins` is now a compatibility wrapper around the
  `kettle-gha-pins` executable.

### Fixed

- Restored `kettle-gha-pins` as a normal runtime dependency now that 0.2.1
  supports the full `kettle-dev` Ruby floor.

- Appraisal rake task specs now rely on kettle-test's `silent_stream`
  integration instead of stubbing `Object#warn`, which is not supported under
  JRuby 9.4.

## [2.3.9] - 2026-07-21

- TAG: [v2.3.9][2.3.9t]
- COVERAGE: 92.06% -- 4443/4826 lines in 37 files
- BRANCH COVERAGE: 74.09% -- 1733/2339 branches in 37 files
- 54.64% documented

### Fixed

- `kettle-release` now records a short-lived gem.coop release-state cache-bust
  marker after publishing, and `kettle-changelog --release-state` uses it to
  refresh just-published gem version lookups.

- `dep-heads.yml` now runs each engine directly from
  `gemfiles/dep_heads.gemfile`, avoiding `Appraisal.root.gemfile` bootstrap
  failures with RubyGems/Bundler and gem.coop before the dep-heads appraisal is
  selected.

## [2.3.8] - 2026-07-21

- TAG: [v2.3.8][2.3.8t]
- COVERAGE: 91.98% -- 4379/4761 lines in 36 files
- BRANCH COVERAGE: 73.91% -- 1711/2315 branches in 36 files
- 56.04% documented

### Added

- `kettle-changelog --release-state` now reports an `ahead` value counting
  commits from the latest release tag to the local default branch when
  available.
- `kettle-release` now accepts `--skip-remotes` and
  `K_RELEASE_SKIP_REMOTES` to exclude temporarily unavailable git remotes from
  release fetch/push parity checks.
- `kettle-release` now creates or reuses an open GitHub pull request for
  non-trunk release branches before waiting for GitHub Actions, so
  pull-request-only workflows start after release branch pushes.

### Changed

- kettle-jem-template-20260720-002 - Generated development Gemfiles now use the
  released `tree_sitter_language_pack` gem 1.13.3 or newer by default.
- kettle-jem-template-20260720-003 - Generated StructuredMerge Git diff driver
  config now uses the installed `smorg-rb` Ruby driver name.
- kettle-jem-template-20260720-005 - Generated README Support & Community rows
  now include a RubyForum help badge.

## [2.3.7] - 2026-07-18

- TAG: [v2.3.7][2.3.7t]
- COVERAGE: 91.84% -- 4311/4694 lines in 36 files
- BRANCH COVERAGE: 74.20% -- 1694/2283 branches in 36 files
- 56.25% documented

### Fixed

- `kettle-gha-sha-pins` now canonicalizes duplicate equivalent action tags,
  preferring explicit release tags such as `v7.0.0` over major-line aliases
  such as `v7`, so adjacent version comments do not flip between spellings.

## [2.3.6] - 2026-07-17

- TAG: [v2.3.6][2.3.6t]
- COVERAGE: 91.85% -- 4292/4673 lines in 36 files
- BRANCH COVERAGE: 73.94% -- 1685/2279 branches in 36 files
- 56.67% documented

### Added

- `kettle-release` now accepts `--ci-workflows` and
  `K_RELEASE_CI_WORKFLOWS` to monitor an explicit workflow subset at the CI
  wait step while retaining the default behavior of waiting for all applicable
  workflows.

### Changed

- kettle-jem-template-20260716-002 - Generated gemspec manifests now ship fewer
  repository-only files by default to reduce downstream distro packaging churn.

### Fixed

- `kettle-release --ci-workflows` now rejects a missing value when the next
  token is another flag, and the release CI workflow subset APIs now have
  matching RBS signatures.

## [2.3.5] - 2026-07-16

- TAG: [v2.3.5][2.3.5t]
- COVERAGE: 92.03% -- 4297/4669 lines in 36 files
- BRANCH COVERAGE: 74.02% -- 1684/2275 branches in 36 files
- 56.88% documented

### Changed

- Updated the `kettle-rb` runtime dependency floor to `>= 0.1.2`.

### Fixed

- `kettle-changelog` now honors `K_CHANGELOG_GEM_NAME` before root gemspec
  discovery, allowing root changelogs for gem families to query live release
  data without requiring a synthetic root gemspec.

## [2.3.4] - 2026-07-14

- TAG: [v2.3.4][2.3.4t]
- COVERAGE: 91.96% -- 4292/4667 lines in 36 files
- BRANCH COVERAGE: 74.22% -- 1687/2273 branches in 36 files
- 56.88% documented

### Fixed

- GitHub Actions release monitoring now ignores `scorecard-analysis.yml` by
  default, matching other maintenance workflows that may not start on release
  commits.

## [2.3.3] - 2026-07-13

- TAG: [v2.3.3][2.3.3t]
- COVERAGE: 91.62% -- 4276/4667 lines in 36 files
- BRANCH COVERAGE: 72.80% -- 1678/2305 branches in 36 files
- 56.88% documented

### Fixed

- AST-based version edits now apply Prism byte offsets as byte offsets, avoiding
  corrupted Ruby when non-ASCII content appears before the edited string.

## [2.3.2] - 2026-07-13

- TAG: [v2.3.2][2.3.2t]
- COVERAGE: 91.89% -- 4285/4663 lines in 36 files
- BRANCH COVERAGE: 73.15% -- 1686/2305 branches in 36 files
- 57.09% documented

### Fixed

- `kettle-bump patch` now finalizes prerelease versions to the matching full
  release instead of rejecting non-numeric prerelease segments.

## [2.3.1] - 2026-07-10

- TAG: [v2.3.1][2.3.1t]
- COVERAGE: 91.69% -- 4271/4658 lines in 36 files
- BRANCH COVERAGE: 73.08% -- 1683/2303 branches in 36 files
- 57.30% documented

### Added

- `kettle-pre-release` now skips volatile star-history image URLs by default
  during Markdown image validation, and accepts additional
  `.kettle-family.yml` or `KETTLE_FAMILY_CONFIG` patterns under
  `pre_release.image_url_skip_patterns`.

- `kettle-release --skip-bundle-audit` and `KETTLE_DEV_SKIP_BUNDLE_AUDIT=true`
  now disable the release-flow `bundle:audit` and `bundle:audit:update` rake
  defaults so a known advisory can be handled outside the automated release.

### Changed

- `require "kettle/dev"` no longer loads `version_gem` by default; require
  `kettle/dev/version_gem` for the optional `VersionGem::Basic` extension.

### Fixed

- Legacy-engine CI workflows now install Bundler gems under
  `${RUNNER_TEMP}/bundle` instead of `vendor/bundle`, and RuboCop now excludes
  nested `vendor/` trees such as `gemfiles/vendor`.

- `kettle-release --skip-bundle-audit` now also prefixes release `bin/rake`
  commands with `KETTLE_DEV_SKIP_BUNDLE_AUDIT=true`, ensuring the skip reaches
  the rake process during release checks.

## [2.3.0] - 2026-07-02

- TAG: [v2.3.0][2.3.0t]
- COVERAGE: 91.95% -- 4216/4585 lines in 35 files
- BRANCH COVERAGE: 73.19% -- 1660/2268 branches in 35 files
- 58.02% documented

### Added

- `Kettle::Dev::VersionBump` now exposes the reusable engine behind
  `kettle-bump`, so other tools can share version detection, target resolution,
  Prism edits, and write behavior without shelling out or duplicating logic.

## [2.2.25] - 2026-07-01

- TAG: [v2.2.25][2.2.25t]
- COVERAGE: 91.66% -- 4186/4567 lines in 34 files
- BRANCH COVERAGE: 72.82% -- 1650/2266 branches in 34 files
- 59.34% documented

### Changed

- Updated the `kettle-rb` runtime dependency floor to 0.1.1.

### Fixed

- Package configured license files in gem release file lists.

- YAML config loading remains compatible with older Psych releases on legacy
  Rubies that do not provide `YAML.safe_load_file` or keyword options for
  `YAML.safe_load`.

- JRuby head CI now skips the release-flow specs that trigger repeated
  `jopenssl/load.rb` warning floods while the upstream JRuby/JOpenSSL recursion
  is investigated.

## [2.2.24] - 2026-06-29

- TAG: [v2.2.24][2.2.24t]
- COVERAGE: 92.02% -- 4198/4562 lines in 34 files
- BRANCH COVERAGE: 73.26% -- 1660/2266 branches in 34 files
- 59.83% documented

### Changed

- `Kettle::EmojiRegex::REGEX` now delegates to the `emoji_regex` runtime
  dependency instead of carrying a vendored regex snapshot.
- `kettle-pre-release` image URL validation and `kettle-gha-sha-pins` action
  resolution now report cached and live checks with progress bars instead of
  printing every checked URL or action reference.

## [2.2.23] - 2026-06-28

- TAG: [v2.2.23][2.2.23t]
- COVERAGE: 91.63% -- 4160/4540 lines in 33 files
- BRANCH COVERAGE: 72.82% -- 1650/2266 branches in 33 files
- 61.04% documented

### Fixed

- `kettle-release` no longer tries to switch an active local/dev checkout when
  the release is running from that same branch-stack checkout.

## [2.2.22] - 2026-06-28

- TAG: [v2.2.22][2.2.22t]
- COVERAGE: 92.01% -- 4171/4533 lines in 33 files
- BRANCH COVERAGE: 73.08% -- 1653/2262 branches in 33 files
- 61.04% documented

### Fixed

- `kettle-release` now passes the exact built gem artifact to `bin/gem_checksums`
  so stale packages in `pkg/` cannot cause checksums for the wrong version.

## [2.2.21] - 2026-06-28

- TAG: [v2.2.21][2.2.21t]
- COVERAGE: 92.34% -- 4182/4529 lines in 33 files
- BRANCH COVERAGE: 73.34% -- 1659/2262 branches in 33 files
- 61.04% documented

### Fixed

- `kettle-release` now detects local `.kettle-family.yml` branch-stack release
  targets and skips trunk sync, trunk merge, and trunk checkout for those release
  branches.

## [2.2.20] - 2026-06-27

- TAG: [v2.2.20][2.2.20t]
- COVERAGE: 91.82% -- 4131/4499 lines in 33 files
- BRANCH COVERAGE: 72.73% -- 1632/2244 branches in 33 files
- 61.04% documented

### Added

- `kettle-release` now accepts `skip_steps=...` / `--skip-steps ...` to skip
  selected numbered release steps while running the rest of the release flow.

### Fixed

- `kettle-release` now suppresses inherited Bundler/debug verbosity when running
  release child commands and Appraisal bundle installs.

- `kettle-release` now switches a local `RUBOCOP_LTS_LOCAL` checkout to the
  branch matching the project's selected `rubocop-rubyN_N` style gem before
  running setup and default rake tasks.

- Restored Ruby 2.4 parser compatibility for recent release and CI helper code.

### Changed

- `kettle-release` now reads RuboCop LTS branch selection from
  `Kettle::Rb::CompatMatrix`.

## [2.2.19] - 2026-06-26

- TAG: [v2.2.19][2.2.19t]
- COVERAGE: 91.75% -- 4082/4449 lines in 33 files
- BRANCH COVERAGE: 72.94% -- 1615/2214 branches in 33 files
- 61.84% documented

### Changed

- `kettle-release` now runs `bin/rake appraisal:generate` by default when
  `Appraisals` is present; use `--appraisal-update` or
  `KETTLE_RELEASE_APPRAISAL_TASK=appraisal:update` for the slower lock-resolving
  update path.

## [2.2.18] - 2026-06-24

- TAG: [v2.2.18][2.2.18t]
- COVERAGE: 92.26% -- 4102/4446 lines in 33 files
- BRANCH COVERAGE: 73.19% -- 1616/2208 branches in 33 files
- 62.11% documented

### Fixed

- `kettle-changelog --release-state` now reports the latest released version
  for the current major line as `latest_released`, so branch-stacked gems such
  as `rubocop-lts` do not display the newest release from a different major
  branch in family release-state tables.

## [2.2.17] - 2026-06-24

- TAG: [v2.2.17][2.2.17t]
- COVERAGE: 91.71% -- 4070/4438 lines in 33 files
- BRANCH COVERAGE: 72.73% -- 1600/2200 branches in 33 files
- 62.11% documented

### Added

- Updated to latest kettle-jem template
  - Updated GHA SHA pins
  - Updated dependencies

## [2.2.16] - 2026-06-24

- TAG: [v2.2.16][2.2.16t]
- COVERAGE: 92.23% -- 4093/4438 lines in 33 files
- BRANCH COVERAGE: 73.14% -- 1609/2200 branches in 33 files
- 62.11% documented

### Changed

- `kettle-release` start step 0 now runs `kettle-changelog` after the
  `kettle-pre-release` gates so release prep generates the versioned changelog
  section before the numbered release steps.

### Fixed

- `kettle-release` now invokes `bundle exec kettle-changelog` as an interactive
  command, making the changelog plan banner and confirmation prompt visible
  during release prep.

## [2.2.15] - 2026-06-21

- TAG: [v2.2.15][2.2.15t]
- COVERAGE: 91.83% -- 4067/4429 lines in 33 files
- BRANCH COVERAGE: 72.57% -- 1595/2198 branches in 33 files
- 62.11% documented

### Added

- `kettle-bump pre` now bumps prerelease versions by applying `String#next` to
  the prerelease suffix.

## [2.2.14] - 2026-06-21

- TAG: [v2.2.14][2.2.14t]
- COVERAGE: 92.07% -- 4061/4411 lines in 33 files
- BRANCH COVERAGE: 73.01% -- 1599/2190 branches in 33 files
- 62.11% documented

### Added

- `kettle-changelog --add-unreleased-entry` now adds one non-duplicate entry to
  an existing templated `## [Unreleased]` subsection using the Markly CRISPR
  Markdown adapter, failing closed when the expected section shape is absent.

- Added support for JRuby 10.1 and TruffleRuby 34.0.

### Changed

- Retemplated project metadata and CI/development automation with `kettle-jem` v7.0.0.

- Allow local coverage runs to opt into a vendored `simplecov` checkout through
  the existing nomono `VENDORED_GEMS` workflow.

### Fixed

- Corrected OpenCollective funding metadata to use the `kettle-dev` collective.
- `kettle-gha-sha-pins` now refreshes large action repositories without eagerly
  dereferencing irrelevant annotated tags, bounds GitHub API refreshes with
  explicit timeouts, and falls back to stale cache data only when refresh fails.

- Covered `kettle-changelog --add-unreleased-entry` insertion, duplicate, and
  fail-closed error behavior in the normal development bundle.

- `kettle-changelog` now treats prerelease sections such as `3.0.0.rc3` as
  release sections when detecting or updating the latest prepared release.
- Fixed seed-dependent coverage by starting SimpleCov before test support loads,
  covering `version.rb`, and making rake task specs cover their task wiring
  branches deterministically.

## [2.2.13] - 2026-06-18

- TAG: [v2.2.13][2.2.13t]
- COVERAGE: 92.15% -- 3931/4266 lines in 28 files
- BRANCH COVERAGE: 73.97% -- 1566/2117 branches in 28 files
- 63.76% documented

### Fixed

- `kettle-release` now treats `kettle-pre-release` as step 0, so any
  `start_step` greater than 0 skips pre-release gates and resumes directly at
  the requested numbered release step.

## [2.2.12] - 2026-06-18

- TAG: [v2.2.12][2.2.12t]
- COVERAGE: 92.52% -- 3947/4266 lines in 28 files
- BRANCH COVERAGE: 74.11% -- 1569/2117 branches in 28 files
- 63.76% documented

### Added

- Added `--version VERSION` support to `kettle-changelog` and `kettle-release`
  for shim gems whose release version is intentionally sourced outside the local
  `lib/**/version.rb` file.

### Fixed

- Updated `kettle-changelog` and `kettle-pre-release` help text to match current
  coverage generation, documentation stats, and image URL cache behavior.

## [2.2.11] - 2026-06-17

- TAG: [v2.2.11][2.2.11t]
- COVERAGE: 92.38% -- 3928/4252 lines in 28 files
- BRANCH COVERAGE: 73.97% -- 1560/2109 branches in 28 files
- 64.06% documented

### Fixed

- `kettle-bump` now prefers the gemspec-declared version file before scanning
  `lib/**/version.rb`, so compatibility alias version files do not block version
  bumps.

## [2.2.10] - 2026-06-16

- TAG: [v2.2.10][2.2.10t]
- COVERAGE: 92.24% -- 3911/4240 lines in 28 files
- BRANCH COVERAGE: 73.87% -- 1552/2101 branches in 28 files
- 64.35% documented

### Changed

- `kettle-pre-release` now caches successful Markdown image URL validations in
  the global kettle-dev state cache for seven days to avoid repeated network
  HEAD requests during release readiness checks.

## [2.2.9] - 2026-06-14

- TAG: [v2.2.9][2.2.9t]
- COVERAGE: 92.57% -- 3863/4173 lines in 28 files
- BRANCH COVERAGE: 74.00% -- 1534/2073 branches in 28 files
- 65.38% documented

### Fixed

- `kettle-gha-sha-pins --check` no longer fails solely because releases outside
  the selected `--upgrade` policy exist, and `kettle-pre-release` now validates
  workflow pins with the inclusive `major` policy used for release readiness.

- `kettle-gha-sha-pins --write` now handles major-line adjacent version comments
  such as `# v7` idempotently instead of repeatedly planning the same
  `update_version_comment` change.

## [2.2.8] - 2026-06-13

- TAG: [v2.2.8][2.2.8t]
- COVERAGE: 92.40% -- 3854/4171 lines in 28 files
- BRANCH COVERAGE: 73.37% -- 1521/2073 branches in 28 files
- 66.02% documented

### Fixed

#### Changelog

- `kettle-changelog --release-state` now reports a clear family-root hint when
  run outside a single gem instead of raising a missing `CHANGELOG.md` stack
  trace.
- `kettle-changelog --release-state` now reports a successful no-changelog state
  for individual gems that do not have a `CHANGELOG.md`.

## [2.2.7] - 2026-06-13

- TAG: [v2.2.7][2.2.7t]
- COVERAGE: 92.36% -- 3843/4161 lines in 28 files
- BRANCH COVERAGE: 73.54% -- 1520/2067 branches in 28 files
- 66.02% documented

### Added

#### Changelog

- Added `kettle-changelog --release-state` / `--release-status` with optional
  `--json` output for single-gem changelog release state reporting.
- Added a richer `Kettle::Dev::ChangelogCLI#release_state` API that reports the
  latest released version, latest changelog release section, and pending
  changelog sources.

## [2.2.6] - 2026-06-13

- TAG: [v2.2.6][2.2.6t]
- COVERAGE: 92.27% -- 3833/4154 lines in 28 files
- BRANCH COVERAGE: 73.51% -- 1518/2065 branches in 28 files
- 66.67% documented

### Added

#### Changelog

- Added `kettle-changelog --pending-release`, a non-mutating query that exits
  successfully when `CHANGELOG.md` has unreleased entries or its most recent
  release section has not been published yet.

## [2.2.5] - 2026-06-13

- TAG: [v2.2.5][2.2.5t]
- COVERAGE: 92.29% -- 3818/4137 lines in 28 files
- BRANCH COVERAGE: 73.49% -- 1516/2063 branches in 28 files
- 67.00% documented

### Changed

- `kettle-gha-sha-pins --upgrade major` now supports major-line action tags
  such as `v2`, while patch and minor upgrade targeting remain limited to full
  `x.y.z` SemVer tags.

### Fixed

- `kettle-gha-sha-pins` persistent cache writes no longer crash for actions
  whose releases and tags only include major-line versions such as `v2`.

## [2.2.4] - 2026-06-12

- TAG: [v2.2.4][2.2.4t]
- COVERAGE: 92.18% -- 3806/4129 lines in 28 files
- BRANCH COVERAGE: 73.26% -- 1507/2057 branches in 28 files
- 67.00% documented

### Changed

- Retemplated generated project files with the current `kettle-jem` template,
  refreshing development dependency floors, binstubs, README metadata, and RBS
  validation workflow output.

### Fixed

- `kettle-gha-sha-pins --upgrade` no longer downgrades action pins when the
  current SHA matches a newer version-like tag that is a prerelease or lacks a
  GitHub Release, including transferred action repositories that require GitHub
  API redirects.

## [2.2.3] - 2026-06-09

- TAG: [v2.2.3][2.2.3t]
- COVERAGE: 91.76% -- 3762/4100 lines in 28 files
- BRANCH COVERAGE: 72.91% -- 1483/2034 branches in 28 files
- 67.00% documented

### Fixed

- `kettle-pre-release` Markdown image checks now inspect project Markdown files
  instead of recursive scratch output such as `tmp/template_test`.

## [2.2.2] - 2026-06-09

- TAG: [v2.2.2][2.2.2t]
- COVERAGE: 92.04% -- 3758/4083 lines in 28 files
- BRANCH COVERAGE: 72.95% -- 1478/2026 branches in 28 files
- 66.83% documented

### Changed

- `kettle-gha-sha-pins` now scans only the selected workflow directory,
  defaulting to `.github/workflows`, instead of recursively searching every
  nested `.github/workflows` directory under the project root.

### Fixed

- Updated generated project metadata links to use the migrated `kettle-dev`
  GitHub organization, including README QLTY badge URLs.

## [2.2.1] - 2026-06-09

- TAG: [v2.2.1][2.2.1t]
- COVERAGE: 91.61% -- 3736/4078 lines in 28 files
- BRANCH COVERAGE: 72.78% -- 1473/2024 branches in 28 files
- 66.83% documented

### Fixed

- `Kettle::Dev::GemSpecReader` now falls back to the migrated `kettle-dev`
  GitHub organization when no forge org can be derived.
- `kettle-gha-sha-pins` now persists live ref-to-SHA lookup results in its action
  cache so a dry run followed by `--write` does not repeat the same API calls.
- Restored `docs/CNAME` so the generated documentation site keeps its custom domain.

## [2.2.0] - 2026-06-08

- TAG: [v2.2.0][2.2.0t]
- COVERAGE: 91.51% -- 3710/4054 lines in 28 files
- BRANCH COVERAGE: 72.90% -- 1458/2000 branches in 28 files
- 67.51% documented

### Added

- `kettle-pre-release` now runs `kettle-gha-sha-pins --check` before release
  checks, failing with an outdated-actions summary and recommended
  `kettle-gha-sha-pins --write --upgrade patch` command when workflow actions
  need updated SHA pins.
- `kettle-release` now runs `kettle-pre-release` as a full-release gate before
  release setup starts.
- `kettle-bump` now bumps a single gem's version file before `kettle-changelog`
  release prep.
- `kettle-gha-sha-pins` now shows discovery, workflow scan, and action-resolution
  progress on STDERR for human runs while keeping JSON output quiet by default.
- `kettle-gha-sha-pins` now times action resolution, caches one resolution plan
  per action repository, and uses GitHub REST tag-ref lookups to avoid resolving
  every release tag through individual commit requests.

- `kettle-gha-sha-pins` now keeps a 24-hour persistent action release cache at
  the XDG state location and supports `--refresh-cache` to bypass stale entries
  while preserving cached discoveries for other projects and actions.

### Fixed

- Minitest-only projects now keep `rake test` on the generated
  `Rake::TestTask` path instead of synthesizing a `kettle-test` RSpec task when
  tests live directly under `test/`.

- `kettle-release start_step=10` now waits for GitHub Actions runs for the
  local HEAD SHA to appear before evaluating results, avoiding stale failures
  from the previous branch run.
- Removed the duplicate `cgi` declaration from the `head` appraisal so
  `kettle-release` can regenerate Appraisal gemfiles on Ruby 4.

- `kettle-gha-sha-pins` now treats version-equivalent but unresolved action
  refs as invalid and converts them to release SHAs instead of accepting
  stripped tag names such as `6.0.2` when only `v6.0.2` exists.
- `kettle-gha-sha-pins --write` now refreshes adjacent release-version comments
  when the pinned SHA is current but the comment is stale.
- `kettle-gha-sha-pins` now uses `GH_TOKEN` or `gh auth token` as a fallback
  when `GITHUB_TOKEN` is not set, avoiding false clean reports after
  unauthenticated GitHub API rate limits are exhausted.
- Coverage workflow uploads now pin `codecov/codecov-action` and
  `coverallsapp/github-action` to resolvable release SHAs.

- Ruby 2.4-2.6 CI appraisals now include `backports`, and Ruby 3.0-3.1
  appraisals include `prism`, so `kettle-bump` and GitHub Action SHA pin specs
  run on the supported legacy matrix.

- Legacy CI appraisals now skip `kettle-bump` specs when Prism is unavailable,
  and the Ruby 3.2 appraisal includes `prism` so the specs run where supported.

### Changed

- Retemplated project metadata with the latest `kettle-jem` stack, refreshing
  README and security-policy generated details for the current release line.

- Runtime dependency `kettle-test` now requires 2.0.4 or newer.

## [2.1.1] - 2026-06-06

- TAG: [v2.1.1][2.1.1t]
- COVERAGE: 93.11% -- 2988/3209 lines in 25 files
- BRANCH COVERAGE: 77.58% -- 1218/1570 branches in 25 files
- 75.93% documented

### Added

- `kettle-release --local-ci` for sensitive releases that run `act` locally,
  publish the gem before any git push, create the release tag locally, and push
  commits and tags only after publishing succeeds.

### Changed

- Refreshed kettle-jem template output, including Appraisal2 plugin wiring and
  current dependency floors for `appraisal2`, `appraisal2-rubocop`, and
  `version_gem`.

## [2.1.0] - 2026-06-06

- TAG: [v2.1.0][2.1.0t]
- COVERAGE: 93.52% -- 2973/3179 lines in 25 files
- BRANCH COVERAGE: 77.58% -- 1204/1552 branches in 25 files
- 75.93% documented

### Changed

- `appraisal:install` now uses `appraisal generate-install`, and
  `appraisal:update` now uses `appraisal generate-update`, preserving
  generation-before-resolution behavior after Appraisal2 split pure install and
  update commands from generation.
- Appraisal gemfile cleanup is no longer run directly by kettle-dev appraisal
  tasks; projects that need generated gemfile normalization should load an
  Appraisal2 plugin hook such as `appraisal2-rubocop`.

## [2.0.8] - 2026-06-02

- TAG: [v2.0.8][2.0.8t]
- COVERAGE: 92.83% -- 2953/3181 lines in 25 files
- BRANCH COVERAGE: 76.59% -- 1201/1568 branches in 25 files
- 75.93% documented

### Fixed

- `appraisal:update` now installs the `Appraisal.root.gemfile` bundle before
  running `bundle update --bundler`, fixing first-run release failures when the
  Appraisal root lockfile does not exist yet.

## [2.0.7] - 2026-06-01

- TAG: [v2.0.7][2.0.7t]
- COVERAGE: 93.14% -- 2961/3179 lines in 25 files
- BRANCH COVERAGE: 76.88% -- 1204/1566 branches in 25 files
- 75.93% documented

### Changed

- Runtime dependency `kettle-test` now requires 2.0.2 or newer.
- Generated style Gemfiles now use the current RuboCop-LTS Ruby 2.4 floor.
- Lint / style updates

### Fixed

- Avoided moving mocked CI task input reads into a background thread for
  non-interactive runs, fixing TruffleRuby v23.0-v23.1 CI stability.

## [2.0.6] - 2026-05-31

- TAG: [v2.0.6][2.0.6t]
- COVERAGE: 93.14% -- 2961/3179 lines in 25 files
- BRANCH COVERAGE: 76.95% -- 1205/1566 branches in 25 files
- 75.93% documented

### Added

- `kettle-changelog` now supports monorepo version files, allowing release
  preparation for gems whose version constants live below subproject roots.

### Changed

- Refreshed generated `kettle-jem` template output, including
  `.structuredmerge` configuration, Git diff driver setup, RuboCop-LTS RSpec
  style dependencies, and release task wiring.

- Updated the user-maintained README usage sections to describe the current
  kettle-dev task, changelog, release, and kettle-jem setup boundaries.
- Corrected the deprecated `kettle-dev-setup` documentation and shim output to
  point at the real `kettle-jem setup` command.
- Refreshed the README with current kettle-jem logo templating, including
  128px HTML logo output and the Ruby Toolbox language-logo link.
- Moved the generated related-org and Ruby README logos from the H1 to the
  Synopsis heading with the current kettle-jem width defaults.
- Added the generated README note that identifies kettle-jem and
  StructuredMerge as the templating and merge-contract tooling.

### Fixed

- Regenerated the spec helper so `kettle-dev` is required only after coverage
  bootstrap setup.

## [2.0.5] - 2026-05-28

- TAG: [v2.0.5][2.0.5t]
- COVERAGE: 93.46% -- 2972/3180 lines in 25 files
- BRANCH COVERAGE: 76.94% -- 1208/1570 branches in 25 files
- 76.40% documented

### Added

- Added `appraisal:generate`, which regenerates Appraisal gemfiles inside the
  `Appraisal.root.gemfile` bundle context without resolving appraisal locks.

## [2.0.4] - 2026-05-27

- TAG: [v2.0.4][2.0.4t]
- COVERAGE: 94.42% -- 2944/3118 lines in 24 files
- BRANCH COVERAGE: 78.22% -- 1203/1538 branches in 24 files
- 76.40% documented

### Fixed

- `kettle-changelog` now refuses to merge Unreleased entries or generated
  metadata into a release section when `version.rb` already matches the latest
  published version for that release line; bump the version before preparing a
  new changelog release.
- The `yard` rake spec now reloads the task file directly and uses Ruby
  2.4-compatible cleanup syntax, fixing order-dependent CI failures across the
  appraisal matrix.
- The `yard` rake fallback task now remains registered with kettle-dev defaults
  when the optional `yard` gem is unavailable in an appraisal environment.
- The Rakefile now falls back to a stub `kettle:jem:selftest` task when the
  installed `kettle-jem` package does not expose rake task installation.

## [2.0.3] - 2026-05-27

- TAG: [v2.0.3][2.0.3t]
- COVERAGE: 94.62% -- 2956/3124 lines in 24 files
- BRANCH COVERAGE: 78.21% -- 1206/1542 branches in 24 files
- 76.40% documented

### Fixed

- The default rake task now includes documentation generation via `yard`, so
  documentation plugin post-processing runs during `bin/rake`.
- `kettle-changelog` now updates the current changelog release in place when
  Unreleased has pending entries or the release section is missing generated
  coverage/documentation metadata, even if the version is already the latest
  known release.

## [2.0.2] - 2026-05-27

- TAG: [v2.0.2][2.0.2t]
- COVERAGE: 94.71% -- 2937/3101 lines in 23 files
- BRANCH COVERAGE: 78.23% -- 1200/1534 branches in 23 files
- 76.40% documented

### Changed

- **BREAKING**: Raised the minimum Ruby version to 2.4.0, matching
  `kettle-test` 2.x and its runtime `turbo_tests2` dependency.
- `kettle-test` is now declared as a runtime dependency because the shipped rake
  and changelog tasks invoke `bundle exec kettle-test`.
- Refreshed generated template output for README badge formatting and
  Ruby 2.4-targeted RuboCop LTS style dependencies.

### Removed

- Removed Ruby 2.3 and JRuby 9.1 CI workflows and appraisal gemfiles.

### Fixed

- `ci:act` and release CI monitoring now detect GitHub and GitLab repositories
  when remotes use `git+ssh://` or `ssh://` URLs.
- Appraisal-based CI gemfiles now load the version-appropriate VCR/WebMock
  recording dependencies required by the spec helper without falling back to the
  root Gemfile.
- Reek, RuboCop-LTS, and coverage task specs now run in coverage CI without
  requiring style-only dependencies.
- Reek rake task specs no longer change the process working directory, avoiding
  cross-spec project root leakage under turbo workers.
- `rake reek:update` now raises a normal task error on unexpected reek exits
  instead of calling `Kernel.abort`, so specs can assert the failure path without
  poisoning the process exit status.
- Coverage CI thresholds now match the repository `mise.toml` thresholds instead
  of requiring unreachable 100% line and branch coverage.
- `kettle-changelog` now fails closed when `kettle-test` does not produce the
  expected collated `coverage/coverage.json`, instead of merging worker coverage
  files itself and hiding a coverage integration failure.
- Regenerated templating now keeps `kettle-test` as a runtime dependency only
  instead of duplicating it as both runtime and development dependency.
- Replaced non-capturing `=~` checks with `Regexp#match?` so unlocked/style CI
  stays clean with newer RuboCop performance cops.
- Cleared the remaining `rubocop_gradual` backlog and removed the lock file.

## [2.0.1] - 2026-05-25

- TAG: [v2.0.1][2.0.1t]
- COVERAGE: 94.88% -- 2911/3068 lines in 21 files
- BRANCH COVERAGE: 78.43% -- 1200/1530 branches in 21 files
- 76.25% documented

### Added

- Added `kettle-changelog --update-prep` to refresh the most recent prepared
  release section in place, including date, coverage, documentation stats, and
  any follow-up Unreleased notes.

### Changed

- `kettle-changelog` now generates strict coverage data with
  `bundle exec kettle-test`, preserving the faster `turbo_tests2` runner.
- `kettle-changelog` now treats configured coverage thresholds as a changelog
  preparation gate by default; use `--no-coverage-threshold` or
  `K_CHANGELOG_COVERAGE_HARD=false` to generate changelog metadata without
  threshold enforcement.
- The shared `rake spec` task now delegates to `bundle exec kettle-test`, so
  projects using kettle-dev automatically pick up kettle-test's default
  `turbo_tests2` runner and summary output.
- The shared `:yard` task now installs `yard-fence` and `yard-timekeeper` integrations explicitly so documentation prep and post-processing only run during `rake yard`

- Refreshed generated kettle-jem templates, CI workflows, curated binstubs, and
  local modular Gemfile wiring.
- `kettle-changelog` now auto-selects the correct no-argument action by
  comparing `version.rb`, the latest live release, and the most recent
  CHANGELOG.md release section before prompting for confirmation.
- Updated the development dependency on `kettle-test` to require 2.0.1 or newer.

### Fixed

- Loading YARD during unrelated rake tasks no longer triggers documentation plugin side effects that rewrite or clear `docs/`

- `rake reek:update` now resolves the Reek gem executable directly instead of
  shelling through `bundle exec reek`, avoiding stale project binstubs, and no
  longer fails the default task solely because Reek reported smells while
  refreshing the `REEK` backlog file.
- `rake reek:update` now keeps `REEK` zero-byte when Reek reports no smells
  instead of writing a single blank line.

## [2.0.0] - 2026-02-25

- TAG: [v2.0.0][2.0.0t]
- COVERAGE: 96.06% -- 2683/2793 lines in 20 files
- BRANCH COVERAGE: 79.16% -- 1113/1406 branches in 20 files
- 80.25% documented

### Added

- New `kettle-gh-release` executable for standalone GitHub release creation
  - Extracted from `kettle-release` step 18
  - Useful when RubyGems release succeeded but GitHub release failed
  - Supports explicit version via `version=<VERSION>` argument
  - Auto-detects version from `lib/**/version.rb` if not specified
  - Requires `GITHUB_TOKEN` with `repo:public_repo` (classic) or `contents:write` scope
- Added `.kettle-dev.yml` configuration file for per-file merge options
  - Hybrid format: `defaults` for shared merge options, `patterns` for glob fallbacks, `files` for per-file config
  - Nested directory structure under `files` allows individual file configuration
  - Supports all `Prism::Merge::SmartMerger` options: `preference`, `add_template_only_nodes`, `freeze_token`, `max_recursion_depth`
  - Added `TemplateHelpers.kettle_config`, `.config_for`, `.find_file_config` methods
  - Added spec coverage in `template_helpers_config_spec.rb`

### Changed

- Updated documentation on hostile takeover of RubyGems
  - https://dev.to/galtzo/hostile-takeover-of-rubygems-my-thoughts-5hlo
- **BREAKING**: Replaced `template_manifest.yml` with `.kettle-dev.yml`
  - New hybrid format supports both glob patterns and per-file configuration
  - `TemplateHelpers.load_manifest` now reads from `.kettle-dev.yml` patterns section
  - `TemplateHelpers.strategy_for` checks explicit file configs before falling back to patterns
- **BREAKING**: Simplified `SourceMerger` to fully rely on prism-merge for AST merging
  - Reduced from ~610 lines to ~175 lines (71% reduction)
  - Removed custom newline normalization - prism-merge preserves original formatting
  - Removed custom comment deduplication logic - prism-merge handles this natively
  - All strategies (`:skip`, `:replace`, `:append`, `:merge`) now use prism-merge consistently
  - Freeze blocks (`kettle-dev:freeze` / `kettle-dev:unfreeze`) handled by prism-merge's `freeze_token` option

### Removed

- Removed all `.example` template files from the kettle-dev root and subdirectories
  (27 files). Template files now live exclusively in kettle-jem's `template/` directory.
  Only `.env.local.example` is retained as a dev resource for all destination gems.
- Removed unused methods from `SourceMerger`:
  - `normalize_source` - replaced by prism-merge
  - `normalize_newlines` - prism-merge preserves original formatting
  - `shebang?`, `magic_comment?`, `ruby_magic_comment_key?` - no longer needed
  - Comment extraction/deduplication: `extract_magic_comments`, `extract_file_leading_comments`,
    `create_comment_tuples`, `deduplicate_comment_sequences`, `deduplicate_sequences_pass1`,
    `deduplicate_singles_pass2`, `extract_nodes_with_comments`, `count_blank_lines_before`,
    `build_source_from_nodes`
  - Unused comment restoration: `restore_custom_leading_comments`, `deduplicate_leading_comment_block`,
    `extract_comment_lines`, `normalize_comment`, `leading_comment_block`
- Removed unused constants: `RUBY_MAGIC_COMMENT_KEYS`, `MAGIC_COMMENT_REGEXES`

### Fixed

- Fixed `PrismAppraisals` various comment chunk spacing
  - extract_block_header:
    - skips the blank spacer immediately above an `appraise` block
    - treats any following blank line as the stop boundary once comment lines have been collected
    - prevents preamble comments from being pulled into the first block’s header
  - restores expected ordering:
    - magic comments and their blank line stay at the top
    - block headers remain adjacent to their blocks
    - preserves blank lines between comment chunks
- Fixed `SourceMerger` freeze block location preservation
  - Freeze blocks now stay in their original location in the file structure
  - Skip normalization for files with existing freeze blocks to prevent movement
  - Only include contiguous comments immediately before freeze markers (no arbitrary 3-line lookback)
  - Don't add freeze reminder to files that already have freeze/unfreeze blocks
  - Prevents unrelated comments from being incorrectly captured in freeze block ranges
  - Added comprehensive test coverage for multiple freeze blocks at different nesting levels
- Fixed `TemplateTask` to not override template summary/description with empty strings from destination gemspec
  - Only carries over summary/description when they contain actual content (non-empty)
  - Allows token replacements to work correctly (e.g., `kettle-dev summary` → `my-gem summary`)
  - Prevents empty destination fields from erasing meaningful template values
- Fixed `SourceMerger` magic comment ordering and freeze block protection
  - Magic comments now preserve original order
  - No blank lines inserted between consecutive magic comments
  - Freeze reminder block properly separated from magic comments (not merged)
  - Leverages Prism's built-in `parse_result.magic_comments` API for accurate detection
  - Detects `kettle-dev:freeze/unfreeze` pairs using Prism, then reclassifies as file-level comments to keep blocks intact
  - Removed obsolete `is_magic_comment?` method in favor of Prism's native detection
- Fixed `PrismGemspec` and `PrismGemfile` to use pure Prism AST traversal instead of regex fallbacks
  - Removed regex-based `extract_gemspec_emoji` that parsed `spec.summary =` and `spec.description =` with regex
  - Now traverses Prism AST to find Gem::Specification block, extracts summary/description nodes, and gets literal values
  - Removed regex-based source line detection in `PrismGemfile.merge_gem_calls`
  - Now uses `PrismUtils.statement_key` to find source statements via AST instead of `ln =~ /^\s*source\s+/`
  - Aligns with project goal: move away from regex parsing toward proper AST manipulation with Prism
  - All functionality preserved, tested, and working correctly
- Fixed `PrismGemspec.replace_gemspec_fields` block parameter extraction to use Prism AST
  - **CRITICAL**: Was using regex fallback that incorrectly captured entire block body as parameter name
  - Removed buggy regex fallback in favor of pure Prism AST traversal
  - Now properly extracts block parameter from Prism::BlockParametersNode → Prism::ParametersNode → Prism::RequiredParameterNode
- Fixed `PrismGemspec.replace_gemspec_fields` insert offset calculation for emoji-containing gemspecs
  - **CRITICAL**: Was using character length (`String#length`) instead of byte length (`String#bytesize`) to calculate insert offset
  - When gemspecs contain multi-byte UTF-8 characters (emojis like 🍲), character length != byte length
  - This caused fields to be inserted at wrong byte positions, resulting in truncated strings and massive corruption
  - Changed `body_src.rstrip.length` to `body_src.rstrip.bytesize` for correct byte-offset calculations
  - Prevents gemspec templating from producing corrupted output with truncated dependency lines
  - Added comprehensive debug logging to trace byte offset calculations and edit operations
- Fixed `SourceMerger` variable assignment duplication during merge operations
  - `node_signature` now identifies variable/constant assignments by name only, not full source
  - Previously used full source text as signature, causing duplicates when assignment bodies differed
  - Added specific handlers for: LocalVariableWriteNode, InstanceVariableWriteNode, ClassVariableWriteNode, ConstantWriteNode, GlobalVariableWriteNode
  - Also added handlers for ClassNode and ModuleNode to match by name
  - Example: `gem_version = ...` assignments with different bodies now correctly merge instead of duplicating
  - Prevents `bin/kettle-dev-setup` from creating duplicate variable assignments in gemspecs and other files
  - Added comprehensive specs for variable assignment deduplication and idempotency
- Fixed `SourceMerger` conditional block duplication during merge operations
  - `node_signature` now identifies conditional nodes (if/unless/case) by their predicate only
  - Previously used full source text, causing duplicate blocks when template updates conditional bodies
  - Example: if ENV["FOO"] blocks with different bodies now correctly merge instead of duplicating
  - Prevents `bin/kettle-dev-setup` from creating duplicate if/else blocks in gemfiles
  - Added comprehensive specs for conditional merging behavior and idempotency
- Fixed `PrismGemspec.replace_gemspec_fields` to use byte-aware string operations
  - **CRITICAL**: Was using character-based `String#[]=` with Prism's byte offsets
  - This caused catastrophic corruption when emojis or multi-byte UTF-8 characters were present
  - Symptoms: gemspec blocks duplicated/fragmented, statements escaped outside blocks
  - Now uses `byteslice` and byte-aware concatenation for all edit operations
  - Prevents gemspec templating from producing mangled output with duplicated Gem::Specification blocks
- Fixed `PrismGemspec.replace_gemspec_fields` to correctly handle multi-byte UTF-8 characters (e.g., emojis)
  - Prism uses byte offsets, not character offsets, when parsing Ruby code
  - Changed string slicing from `String#[]` to `String#byteslice` for all offset-based operations
  - Added validation to use `String#bytesize` instead of `String#length` for offset bounds checking
  - Prevents `TypeError: no implicit conversion of nil into String` when gemspecs contain emojis
  - Ensures gemspec field carryover works correctly with emoji in summary/description fields
  - Enhanced error reporting to show backtraces when debug mode is enabled

## [1.2.5] - 2025-11-28

- TAG: [v1.2.5][1.2.5t]
- COVERAGE: 93.53% -- 4726/5053 lines in 31 files
- BRANCH COVERAGE: 76.62% -- 1924/2511 branches in 31 files
- 69.89% documented

### Added

- Comprehensive newline normalization in templated Ruby files:
  - Magic comments (frozen_string_literal, encoding, etc.) always followed by single blank line
  - No more than one consecutive blank line anywhere in file
  - Single newline at end of file (no trailing blank lines)
  - Freeze reminder block now includes blank line before and empty comment line after for better visual separation

### Changed

- Updated `FREEZE_REMINDER` constant to include blank line before and empty comment line after

### Fixed

- Fixed `reminder_present?` to correctly detect freeze reminder when it has leading blank line

## [1.2.4] - 2025-11-28

- TAG: [v1.2.4][1.2.4t]
- COVERAGE: 93.53% -- 4701/5026 lines in 31 files
- BRANCH COVERAGE: 76.61% -- 1913/2497 branches in 31 files
- 69.78% documented

### Fixed

- Fixed comment deduplication in `restore_custom_leading_comments` to prevent accumulation across multiple template runs
  - Comments from destination are now deduplicated before being merged back into result
  - Fixes issue where `:replace` strategy (used by `kettle-dev-setup --force`) would accumulate duplicate comments
  - Ensures truly idempotent behavior when running templating multiple times on the same file
  - Example: `frozen_string_literal` comments no longer multiply from 1→4→5→6 on repeated runs

## [1.2.3] - 2025-11-28vari

- TAG: [v1.2.3][1.2.3t]
- COVERAGE: 93.43% -- 4681/5010 lines in 31 files
- BRANCH COVERAGE: 76.63% -- 1912/2495 branches in 31 files
- 70.55% documented

### Fixed

- Fixed Gemfile parsing to properly deduplicate comments across multiple template runs
  - Implemented two-pass comment deduplication: sequences first, then individual lines
  - Magic comments (frozen_string_literal, encoding, etc.) are now properly deduplicated by content, not line position
  - File-level comments are deduplicated while preserving leading comments attached to statements
  - Ensures idempotent behavior when running templating multiple times on the same file
  - Prevents accumulation of duplicate frozen_string_literal comments and comment blocks

## [1.2.2] - 2025-11-27

- TAG: [v1.2.2][1.2.2t]
- COVERAGE: 93.28% -- 4596/4927 lines in 31 files
- BRANCH COVERAGE: 76.45% -- 1883/2463 branches in 31 files
- 70.00% documented

### Added

- Prism AST-based manipulation of ruby during templating
  - Gemfiles
  - gemspecs
  - .simplecov
- Stop rescuing Exception in certain scenarios (just StandardError)
- Refactored logging logic and documentation
- Prevent self-referential gemfile injection
  - in Gemfiles, gemspecs, and Appraisals
- Improve reliability of coverage and documentation stats
  - in the changelog version heading
  - fails hard when unable to generate stats, unless `--no-strict` provided

## [1.2.1] - 2025-11-25

- TAG: [v1.2.0][1.2.0t]
- COVERAGE: 94.38% -- 4066/4308 lines in 26 files
- BRANCH COVERAGE: 78.81% -- 1674/2124 branches in 26 files
- 69.14% documented

### Changed

- Source merging switched from Regex-based string manipulation to Prism AST-based manipulation
  - Comments are preserved in the resulting file

## [1.1.60] - 2025-11-23

- TAG: [v1.1.60][1.1.60t]
- COVERAGE: 94.38% -- 4066/4308 lines in 26 files
- BRANCH COVERAGE: 78.86% -- 1675/2124 branches in 26 files
- 79.89% documented

### Added

- Add KETTLE_DEV_DEBUG to direnv defaults
- Documentation of the explicit policy violations of RubyGems.org leadership toward open source projects they funded
  - https://www.reddit.com/r/ruby/comments/1ove9vp/rubycentral_hates_this_one_fact/

### Fixed

- Prevent double test runs by ensuring only one of test/coverage/spec are in default task
  - Add debugging when more than one registered

## [1.1.59] - 2025-11-13

- TAG: [v1.1.59][1.1.59t]
- COVERAGE: 94.38% -- 4066/4308 lines in 26 files
- BRANCH COVERAGE: 78.77% -- 1673/2124 branches in 26 files
- 79.89% documented

### Changed

- Improved default devcontainer with common dependencies of most Ruby projects

### Fixed

- token replacement of {TARGET|GEM|NAME}

## [1.1.58] - 2025-11-13

- TAG: [v1.1.58][1.1.58t]
- COVERAGE: 94.41% -- 4067/4308 lines in 26 files
- BRANCH COVERAGE: 78.77% -- 1673/2124 branches in 26 files
- 79.89% documented

### Added

- Ignore more .idea plugin artifacts

### Fixed

- bin/rake yard no longer overrides the .yardignore for checksums

## [1.1.57] - 2025-11-13

- TAG: [v1.1.57][1.1.57t]
- COVERAGE: 94.36% -- 4065/4308 lines in 26 files
- BRANCH COVERAGE: 78.81% -- 1674/2124 branches in 26 files
- 79.89% documented

### Added

- New Rake task: `appraisal:reset` — deletes all Appraisal lockfiles (`gemfiles/*.gemfile.lock`).
- Improved .env.local.example template

### Fixed

- .yardignore more comprehensively ignores directories that are not relevant to documentation

## [1.1.56] - 2025-11-11

- TAG: [v1.1.56][1.1.56t]
- COVERAGE: 94.38% -- 4066/4308 lines in 26 files
- BRANCH COVERAGE: 78.77% -- 1673/2124 branches in 26 files
- 79.89% documented

### Fixed

- Appraisals template merge with existing header
- Don't set opencollective in FUNDING.yml when osc is disabled
- handling of open source collective ENV variables in .envrc templates
- Don't invent an open collective handle when open collective is not enabled

## [1.1.55] - 2025-11-11

- TAG: [v1.1.55][1.1.55t]
- COVERAGE: 94.41% -- 4039/4278 lines in 26 files
- BRANCH COVERAGE: 78.88% -- 1662/2107 branches in 26 files
- 79.89% documented

### Added

- GitLab Pipelines for Ruby 2.7, 3.0, 3.0

## [1.1.54] - 2025-11-11

- TAG: [v1.1.54][1.1.54t]
- COVERAGE: 94.39% -- 4038/4278 lines in 26 files
- BRANCH COVERAGE: 78.88% -- 1662/2107 branches in 26 files
- 79.89% documented

### Added

- .idea/.gitignore is now part of template

## [1.1.53] - 2025-11-10

- TAG: [v1.1.53][1.1.53t]
- COVERAGE: 94.41% -- 4039/4278 lines in 26 files
- BRANCH COVERAGE: 78.93% -- 1663/2107 branches in 26 files
- 79.89% documented

### Added

- Template .yardopts now includes yard-yaml plugin (for CITATION.cff)
- Template now includes a default `.yardopts` file
  - Excludes _.gem, pkg/_.gem and .yardoc from documentation generation

## [1.1.52] - 2025-11-08

- TAG: [v1.1.52][1.1.52t]
- COVERAGE: 94.37% -- 4037/4278 lines in 26 files
- BRANCH COVERAGE: 78.93% -- 1663/2107 branches in 26 files
- 79.89% documented

### Added

- Update documentation

### Changed

- Upgrade to yard-fence v0.8.0

## [1.1.51] - 2025-11-07

- TAG: [v1.1.51][1.1.51t]
- COVERAGE: 94.41% -- 4039/4278 lines in 26 files
- BRANCH COVERAGE: 78.88% -- 1662/2107 branches in 26 files
- 79.89% documented

### Removed

- unused file removed from template
  - functionality was replaced by yard-fence gem

## [1.1.50] - 2025-11-07

- TAG: [v1.1.50][1.1.50t]
- COVERAGE: 94.41% -- 4039/4278 lines in 26 files
- BRANCH COVERAGE: 78.88% -- 1662/2107 branches in 26 files
- 79.89% documented

### Fixed

- invalid documentation (bad find/replace outcomes during templating)

## [1.1.49] - 2025-11-07

- TAG: [v1.1.49][1.1.49t]
- COVERAGE: 94.39% -- 4038/4278 lines in 26 files
- BRANCH COVERAGE: 78.93% -- 1663/2107 branches in 26 files
- 79.89% documented

### Added

- yard-fence for handling braces in fenced code blocks in yard docs
- Improved documentation

## [1.1.48] - 2025-11-06

- TAG: [v1.1.48][1.1.48t]
- COVERAGE: 94.39% -- 4038/4278 lines in 26 files
- BRANCH COVERAGE: 78.93% -- 1663/2107 branches in 26 files
- 79.89% documented

### Fixed

- Typo in markdown link
- Handling of pre-existing gemfile

## [1.1.47] - 2025-11-06

- TAG: [v1.1.47][1.1.47t]
- COVERAGE: 95.68% -- 4054/4237 lines in 26 files
- BRANCH COVERAGE: 80.45% -- 1675/2082 branches in 26 files
- 79.89% documented

### Added

- Handle custom dependencies in Gemfiles gracefully
- Intelligent templating of Appraisals

### Fixed

- Typos in funding links

## [1.1.46] - 2025-11-04

- TAG: [v1.1.46][1.1.46t]
- COVERAGE: 96.25% -- 3958/4112 lines in 26 files
- BRANCH COVERAGE: 80.95% -- 1636/2021 branches in 26 files
- 79.68% documented

### Added

- Validate RBS Types within style workflow

### Fixed

- typos in README.md

## [1.1.45] - 2025-10-31

- TAG: [v1.1.45][1.1.45t]
- COVERAGE: 96.33% -- 3961/4112 lines in 26 files
- BRANCH COVERAGE: 81.00% -- 1637/2021 branches in 26 files
- 79.68% documented

### Changed

- floss-funding related documentation improvements

## [1.1.44] - 2025-10-31

- TAG: [v1.1.44][1.1.44t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Removed

- `exe/*` from `spec.files`, because it is redundant with `spec.bindir` & `spec.executables`
- prepare-commit-msg.example: no longer needed

### Fixed

- prepare-commit-msg git hook: incompatibility between direnv and mise by removing `direnv exec`

## [1.1.43] - 2025-10-30

- TAG: [v1.1.43][1.1.43t]
- COVERAGE: 96.06% -- 3950/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Fixed

- typos in CONTRIBUTING.md used for templating

## [1.1.42] - 2025-10-29

- TAG: [v1.1.42][1.1.42t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Removed

- Exclude `gemfiles/modular/injected.gemfile` from the install/template process, as it is not relevant.

## [1.1.41] - 2025-10-28

- TAG: [v1.1.41][1.1.41t]
- COVERAGE: 96.06% -- 3950/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Changed

- Improved formatting of errors

## [1.1.40] - 2025-10-28

- TAG: [v1.1.40][1.1.40t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Changed

- Improved copy for this gem and templated gems

## [1.1.39] - 2025-10-27

- TAG: [v1.1.39][1.1.39t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Added

- CONTRIBUTING.md.example tailored for the templated gem

### Fixed

- Minor typos

## [1.1.38] - 2025-10-21

- TAG: [v1.1.38][1.1.38t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.80% -- 1633/2021 branches in 26 files
- 79.68% documented

### Changed

- legacy ruby 3.1 pinned to bundler 2.6.9

### Fixed

- Corrected typo: truffleruby-24.1 (targets Ruby 3.3 compatibility)

## [1.1.37] - 2025-10-21

- TAG: [v1.1.37][1.1.37t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.80% -- 1633/2021 branches in 26 files
- 79.68% documented

### Added

- kettle-release: improved --help
- improved documentation of kettle-release
- improved documentation of spec setup with kettle-test

### Changed

- upgrade to kettle-test v1.0.6

## [1.1.36] - 2025-10-20

- TAG: [v1.1.36][1.1.36t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Added

- More documentation of RC situation

### Fixed

- alphabetize dependencies

## [1.1.35] - 2025-10-20

- TAG: [v1.1.35][1.1.35t]
- COVERAGE: 96.04% -- 3949/4112 lines in 26 files
- BRANCH COVERAGE: 80.85% -- 1634/2021 branches in 26 files
- 79.68% documented

### Added

- more documentation of the RC.O situation

### Changed

- upgraded kettle-test to v1.0.5

### Removed

- direct dependency on rspec-pending_for (now provided, and configured, by kettle-test)

## [1.1.34] - 2025-10-20

- TAG: [v1.1.34][1.1.34t]
- COVERAGE: 96.10% -- 3938/4098 lines in 26 files
- BRANCH COVERAGE: 80.92% -- 1624/2007 branches in 26 files
- 79.68% documented

### Changed

- kettle-release: Make step 17 only push the checksum commit; bin/gem_checksums creates the commit internally.
- kettle-release: Ensure a final push of tags occurs after checksums and optional GitHub release; supports an 'all' remote aggregator when configured.

### Fixed

- fixed rake task compatibility with BUNDLE_PATH (i.e. vendored bundle)
  - appraisal tasks
  - bench tasks
  - reek tasks

## [1.1.33] - 2025-10-13

- TAG: [v1.1.33][1.1.33t]
- COVERAGE: 20.83% -- 245/1176 lines in 9 files
- BRANCH COVERAGE: 7.31% -- 43/588 branches in 9 files
- 79.57% documented

### Added

- handling for no open source collective, specified by:
  - `ENV["FUNDING_ORG"]` set to "false", or
  - `ENV["OPENCOLLECTIVE_HANDLE"]` set to "false"
- added codeberg gem source

### Changed

- removed redundant github gem source

### Fixed

- added addressable to optional modular gemfile template, as it is required for kettle-pre-release
- handling of env.ACT conditions in workflows

## [1.1.32] - 2025-10-07

- TAG: [v1.1.32][1.1.32t]
- COVERAGE: 96.39% -- 3929/4076 lines in 26 files
- BRANCH COVERAGE: 81.07% -- 1619/1997 branches in 26 files
- 79.12% documented

### Added

- A top-level note on gem server switch in README.md & template

### Changed

- Switch to cooperative gem server
  - https://gem.coop

## [1.1.31] - 2025-09-21

- TAG: [v1.1.31][1.1.31t]
- COVERAGE: 96.39% -- 3929/4076 lines in 26 files
- BRANCH COVERAGE: 81.07% -- 1619/1997 branches in 26 files
- 79.12% documented

### Fixed

- order of checksums and release / tag reversed
  - remove all possibility of gem rebuild (part of reproducible builds) including checksums in the rebuilt gem

## [1.1.30] - 2025-09-21

- TAG: [v1.1.30][1.1.30t]
- COVERAGE: 96.27% -- 3926/4078 lines in 26 files
- BRANCH COVERAGE: 80.97% -- 1617/1997 branches in 26 files
- 79.12% documented

### Added

- kettle-changelog: handle legacy tag-in-release-heading style
  - convert to tag-in-list style

## [1.1.29] - 2025-09-21

- TAG: [v1.1.29][1.1.29t]
- COVERAGE: 96.19% -- 3861/4014 lines in 26 files
- BRANCH COVERAGE: 80.74% -- 1589/1968 branches in 26 files
- 79.12% documented

### Changed

- Testing release

## [1.1.28] - 2025-09-21

- TAG: [v1.1.28][1.1.28t]
- COVERAGE: 96.19% -- 3861/4014 lines in 26 files
- BRANCH COVERAGE: 80.89% -- 1592/1968 branches in 26 files
- 79.12% documented

### Fixed

- kettle-release: restore compatability with MFA input

## [1.1.27] - 2025-09-20

- TAG: [v1.1.27][1.1.27t]
- COVERAGE: 96.33% -- 3860/4007 lines in 26 files
- BRANCH COVERAGE: 81.09% -- 1591/1962 branches in 26 files
- 79.12% documented

### Changed

- Use obfuscated URLs, and avatars from Open Collective in ReadmeBackers

### Fixed

- improved handling of flaky truffleruby builds in workflow templates
- fixed handling of kettle-release when checksums are present and unchanged causing the gem_checksums script to fail

## [1.1.25] - 2025-09-18

- TAG: [v1.1.25][1.1.25t]
- COVERAGE: 96.87% -- 3708/3828 lines in 26 files
- BRANCH COVERAGE: 81.69% -- 1526/1868 branches in 26 files
- 78.33% documented

### Fixed

- kettle-readme-backers fails gracefully when README_UPDATER_TOKEN is missing from org secrets

## [1.1.24] - 2025-09-17

- TAG: [v1.1.24][1.1.24t]
- COVERAGE: 96.85% -- 3694/3814 lines in 26 files
- BRANCH COVERAGE: 81.81% -- 1520/1858 branches in 26 files
- 78.21% documented

### Added

- Replace template tokens with real minimum ruby versions for runtime and development

### Changed

- consolidated specs

### Fixed

- All .example files are now included in the gem package
- Leaky state in specs

## [1.1.23] - 2025-09-16

- TAG: [v1.1.23][1.1.23t]
- COVERAGE: 96.71% -- 3673/3798 lines in 26 files
- BRANCH COVERAGE: 81.57% -- 1509/1850 branches in 26 files
- 77.97% documented

### Fixed

- GemSpecReader, ReadmeBackers now use shared OpenCollectiveConfig
  - fixes broken opencollective config handling in GemSPecReader

## [1.1.22] - 2025-09-16

- TAG: [v1.1.22][1.1.22t]
- COVERAGE: 96.83% -- 3661/3781 lines in 25 files
- BRANCH COVERAGE: 81.70% -- 1505/1842 branches in 25 files
- 77.01% documented

### Changed

- Revert "🔒️ Use pull_request_target in workflows"
  - It's not relevant to my projects (either this gem or the ones templated)

## [1.1.21] - 2025-09-16

- TAG: [v1.1.21][1.1.21t]
- COVERAGE: 96.83% -- 3661/3781 lines in 25 files
- BRANCH COVERAGE: 81.65% -- 1504/1842 branches in 25 files
- 77.01% documented

### Changed

- improved templating
- improved documentation

### Fixed

- kettle-readme-backers: read correct config file
  - .opencollective.yml in project root

## [1.1.20] - 2025-09-15

- TAG: [v1.1.20][1.1.20t]
- COVERAGE: 96.80% -- 3660/3781 lines in 25 files
- BRANCH COVERAGE: 81.65% -- 1504/1842 branches in 25 files
- 77.01% documented

### Added

- Allow reformating of CHANGELOG.md without version bump
- `--include=GLOB` includes files not otherwise included in default template
- more test coverage

### Fixed

- Add .licenserc.yaml to gem package
- Handling of GFM fenced code blocks in CHANGELOG.md
- Handling of nested list items in CHANGELOG.md
- Handling of blank lines around all headings in CHANGELOG.md

## [1.1.19] - 2025-09-14

- TAG: [v1.1.19][1.1.19t]
- COVERAGE: 96.58% -- 3531/3656 lines in 25 files
- BRANCH COVERAGE: 81.11% -- 1443/1779 branches in 25 files
- 76.88% documented

### Added

- documentation of vcr on Ruby 2.4
- Apache SkyWalking Eyes dependency license check
  - Added to template

### Fixed

- fix duplicate headings in CHANGELOG.md Unreleased section

## [1.1.18] - 2025-09-12

- TAG: [v1.1.18][1.1.18t]
- COVERAGE: 96.24% -- 3477/3613 lines in 25 files
- BRANCH COVERAGE: 81.01% -- 1425/1759 branches in 25 files
- 76.88% documented

### Removed

- remove patreon link from README template

## [1.1.17] - 2025-09-11

- TAG: [v1.1.17][1.1.17t]
- COVERAGE: 96.29% -- 3479/3613 lines in 25 files
- BRANCH COVERAGE: 81.01% -- 1425/1759 branches in 25 files
- 76.88% documented

### Added

- improved documentation
- better organized readme
- badges are more clear & new badge for Ruby Friends Squad on Daily.dev
  - https://app.daily.dev/squads/rubyfriends

### Changed

- update template to version_gem v1.1.9
- right-size funding commit message append width

### Removed

- remove patreon link from README

## [1.1.16] - 2025-09-10

- TAG: [v1.1.16][1.1.16t]
- COVERAGE: 96.24% -- 3477/3613 lines in 25 files
- BRANCH COVERAGE: 81.01% -- 1425/1759 branches in 25 files
- 76.88% documented

### Fixed

- handling of alternate format of Unreleased section in CHANGELOG.md

## [1.1.15] - 2025-09-10

- TAG: [v1.1.15][1.1.15t]
- COVERAGE: 96.29% -- 3479/3613 lines in 25 files
- BRANCH COVERAGE: 80.96% -- 1424/1759 branches in 25 files
- 76.88% documented

### Fixed

- fix appraisals for Ruby v2.7 to use correct x_std_libs

## [1.1.14] - 2025-09-10

- TAG: [v1.1.14][1.1.14t]
- COVERAGE: 96.24% -- 3477/3613 lines in 25 files
- BRANCH COVERAGE: 80.96% -- 1424/1759 branches in 25 files
- 76.88% documented

### Changed

- use current x_std_libs modular gemfile for all appraisals that are pinned to current ruby
- fix appraisals for Ruby v2 to use correct version of erb

## [1.1.13] - 2025-09-09

- TAG: [v1.1.13][1.1.13t]
- COVERAGE: 96.29% -- 3479/3613 lines in 25 files
- BRANCH COVERAGE: 80.96% -- 1424/1759 branches in 25 files
- 76.88% documented

### Fixed

- include .rubocop_rspec.yml during install / template task's file copy
- kettle-dev-setup now honors `--force` option

## [1.1.12] - 2025-09-09

- TAG: [v1.1.12][1.1.12t]
- COVERAGE: 94.84% -- 3422/3608 lines in 25 files
- BRANCH COVERAGE: 78.97% -- 1386/1755 branches in 25 files
- 76.88% documented

### Changed

- improve Gemfile updates during kettle-dev-setup
- git origin-based funding_org derivation during setup

## [1.1.11] - 2025-09-08

- TAG: [v1.1.11][1.1.11t]
- COVERAGE: 96.56% -- 3396/3517 lines in 24 files
- BRANCH COVERAGE: 81.33% -- 1385/1703 branches in 24 files
- 77.06% documented

### Changed

- move kettle-dev-setup logic into Kettle::Dev::SetupCLI

### Fixed

- gem dependency detection in kettle-dev-setup to prevent duplication

## [1.1.10] - 2025-09-08

- TAG: [v1.1.10][1.1.10t]
- COVERAGE: 97.14% -- 3256/3352 lines in 23 files
- BRANCH COVERAGE: 81.91% -- 1345/1642 branches in 23 files
- 76.65% documented

### Added

- Improve documentation
  - Fix an internal link in README.md

### Changed

- template task no longer overwrites CHANGELOG.md completely
  - attempts to retain existing release notes content

### Fixed

- Fix a typo in the README.md

### Fixed

- fix typo in the path to x_std_libs.gemfile

## [1.1.9] - 2025-09-07

- TAG: [v1.1.9][1.1.9t]
- COVERAGE: 97.11% -- 3255/3352 lines in 23 files
- BRANCH COVERAGE: 81.91% -- 1345/1642 branches in 23 files
- 76.65% documented

### Added

- badge for current runtime heads in example readme

### Fixed

- Add gemfiles/modular/x_std_libs.gemfile & injected.gemfile to template
- example version of gemfiles/modular/runtime_heads.gemfile
  - necessary to avoid deps on recording gems in the template

## [1.1.8] - 2025-09-07

- TAG: [v1.1.8][1.1.8t]
- COVERAGE: 97.16% -- 3246/3341 lines in 23 files
- BRANCH COVERAGE: 81.95% -- 1344/1640 branches in 23 files
- 76.97% documented

### Added

- add .aiignore to the template
- add .rubocop_rspec.yml to the template
- gemfiles/modular/x_std_libs pattern to template, including:
  - erb
  - mutex_m
  - stringio
- gemfiles/modular/debug.gemfile
- gemfiles/modular/runtime_heads.gemfile
- .github/workflows/dep-heads.yml
- (performance) filter and prioritize example files in the `.github` directory
- added codecov config to the template
- Kettle::Dev.default_registered?

### Fixed

- run specs as part of the test task

## [1.1.7] - 2025-09-06

- TAG: [v1.1.7][1.1.7t]
- COVERAGE: 97.12% -- 3237/3333 lines in 23 files
- BRANCH COVERAGE: 81.95% -- 1344/1640 branches in 23 files
- 76.97% documented

### Added

- rake task - `appraisal:install`
  - initial setup for projects that didn't previously use Appraisal

### Changed

- .git-hooks/commit-msg allows commit if gitmoji-regex is unavailable
- simplified `*Task` classes' `task_abort` methods to just raise Kettle::Dev::Error
  - Allows caller to decide how to handle.

### Removed

- addressable, rake runtime dependencies
  - moved to optional, or development dependencies

### Fixed

- Fix local CI via act for templated workflows (skip JRuby in nektos/act locally)

## [1.1.6] - 2025-09-05

- TAG: [v1.1.6][1.1.6t]
- COVERAGE: 97.06% -- 3241/3339 lines in 23 files
- BRANCH COVERAGE: 81.83% -- 1347/1646 branches in 23 files
- 76.97% documented

### Fixed

- bin/rake test works for minitest

## [1.1.5] - 2025-09-04

- TAG: [v1.1.5][1.1.5t]
- COVERAGE: 33.87% -- 1125/3322 lines in 22 files
- BRANCH COVERAGE: 22.04% -- 361/1638 branches in 22 files
- 76.83% documented

### Added

- kettle-pre-release: run re-release checks on a library
  - validate URLs of image assets in Markdown files
- honor ENV["FUNDING_FORGE"] set to "false" as intentional disabling of funding-related logic.
- Add CLI Option --only passthrough from kettle-dev-setup to Installation Task
- Comprehensive documentation of all exe/ scripts in README.md
- add gitlab pipeline result to ci:act
- highlight SHA discrepancies in ci:act task header info
- how to set up forge tokens for ci:act, and other tools, instructions for README.md

### Changed

- expanded use of adapter patterns (Exit, Git, and Input)
- refactored and improved structure of code, more resilient
- kettle-release: do not abort immediately on CI failure; continue checking all workflows, summarize results, and prompt to (c)ontinue or (q)uit (reuses ci:act-style summary)

### Removed

- defensive NameError handling in ChangelogCLI.abort method

### Fixed

- replace token `{OPENCOLLECTIVE|ORG_NAME}` with funding org name
- prefer .example version of .git-hooks
- kettle-commit-msg now runs via rubygems (not bundler) so it will work via a system gem
- fixed logic for handling derivation of forge and funding URLs
- allow commits to succeed if dependencies are missing or broken
- RBS types documentation for GemSpecReader

## [1.1.4] - 2025-09-02

- TAG: [v1.1.4][1.1.4t]
- COVERAGE: 67.64% -- 554/819 lines in 9 files
- BRANCH COVERAGE: 53.25% -- 221/415 branches in 9 files
- 76.22% documented

### Fixed

- documentation of rake tasks from this gem no longer includes standard gem tasks
- kettle-dev-setup: package bin/setup so setup can copy it
- kettle_dev_install task: set executable flag for .git-hooks script when installing

## [1.1.3] - 2025-09-02

- TAG: [v1.1.3][1.1.3t]
- COVERAGE: 97.14% -- 2857/2941 lines in 22 files
- BRANCH COVERAGE: 82.29% -- 1194/1451 branches in 22 files
- 76.22% documented

### Changed

- URL for migrating repo to CodeBerg:
  - https://codeberg.org/repo/migrate

### Fixed

- Stop double defining DEBUGGING constant

## [1.1.2] - 2025-09-02

- TAG: [v1.1.2][1.1.2t]
- COVERAGE: 97.14% -- 2858/2942 lines in 22 files
- BRANCH COVERAGE: 82.29% -- 1194/1451 branches in 22 files
- 76.76% documented

### Added

- .gitlab-ci.yml documentation (in example)
- kettle-dvcs script for setting up DVCS, and checking status of remotes
  - https://railsbling.com/posts/dvcs/put_the_d_in_dvcs/
- kettle-dvcs --status: prefix "ahead by N" with ✅️ when N==0, and 🔴 when N>0
- kettle-dvcs --status: also prints a Local status section comparing local HEAD to origin/<branch>, and keeps origin visible via that section
- Document kettle-dvcs CLI in README (usage, options, examples)
- RBS types for Kettle::Dev::DvcsCLI and inline YARD docs on CLI
- Specs for DvcsCLI covering remote normalization, fetch outcomes, and README updates

### Changed

- major spec refactoring

### Fixed

- (linting) rspec-pending_for 0.0.17+ (example gemspec)

## [1.1.1] - 2025-09-02

- TAG: [v1.1.1][1.1.1t]
- COVERAGE: 97.04% -- 2655/2736 lines in 21 files
- BRANCH COVERAGE: 82.21% -- 1109/1349 branches in 21 files
- 76.81% documented

### Added

- .simplecov.example - keeps it generic
- improved documentation on automatic release script
- .gitlab-ci.yml documentation

### Fixed

- reduce extra leading whitespace in info table column 2

## [1.1.0] - 2025-09-02

- TAG: [v1.1.0][1.1.0t]
- COVERAGE: 97.03% -- 2649/2730 lines in 21 files
- BRANCH COVERAGE: 82.16% -- 1105/1345 branches in 21 files
- 76.81% documented

### Added

- exe/kettle-dev-setup - bootstrap templating in any RubyGem

### Removed

- all runtime deps
  - dependencies haven't really changed; will be injected into the gemspec of the including gem
  - **almost** a breaking change; but this gem re-templates other gems
  - so non-breaking via re-templating.

## [1.0.27] - 2025-09-01

- TAG: [v1.0.27][1.0.27t]
- COVERAGE: 97.77% -- 2629/2689 lines in 22 files
- BRANCH COVERAGE: 82.40% -- 1100/1335 branches in 22 files
- 76.47% documented

### Changed

- Use semver version dependency (~> 1.0) on kettle-dev when templating

### Removed

- dependency on version_gem (backwards compatible change)

## [1.0.26] - 2025-09-01

- TAG: [v1.0.26][1.0.26t]
- COVERAGE: 97.81% -- 2630/2689 lines in 22 files
- BRANCH COVERAGE: 82.40% -- 1100/1335 branches in 22 files
- 75.00% documented

### Fixed

- .env.local.example is now included in the packaged gem
  - making the copy by install / template tasks possible

## [1.0.25] - 2025-08-31

- TAG: [v1.0.25][1.0.25t]
- COVERAGE: 97.81% -- 2630/2689 lines in 22 files
- BRANCH COVERAGE: 82.40% -- 1100/1335 branches in 22 files
- 75.00% documented

### Added

- test that .env.local.example is copied by install / template tasks

### Changed

- update Appraisals.example template's instructions for updating appraisals

## [1.0.24] - 2025-08-31

- TAG: [v1.0.24][1.0.24t]
- COVERAGE: 97.51% -- 2625/2692 lines in 22 files
- BRANCH COVERAGE: 81.97% -- 1096/1337 branches in 22 files
- 75.00% documented

### Added

- improved documentation
- more badges in README (gem & template)
- integration test for kettle-changelog using CHANGELOG.md.
- integration test for kettle-changelog using KEEP_A_CHANGELOG.md.

### Changed

- add output to error handling related to release creation on GitHub
- refactored Kettle::Dev::Tasks::CITask.abort => task_abort
  - Avoids method name clash with ExitAdapter
  - follows the pattern of other Kettle::Dev::Tasks modules
- move --help handling for kettle-changelog to kettle-changelog itself

### Fixed

- typos in README for gem & template
- kettle-changelog: more robust in retention of version chunks, and markdown link refs, that are not relevant to the chunk being added
- rearrange footer links in changelog by order, newest first, oldest last
- `Kettle::Dev::Tasks::CITask.act` returns properly when running non-interactively
- replace Underscores with Dashes in Gem Names for [🚎yard-head] link

## [1.0.23] - 2025-08-30

- TAG: [v1.0.23][1.0.23t]
- COVERAGE: 97.75% -- 2428/2484 lines in 21 files
- BRANCH COVERAGE: 81.76% -- 1013/1239 branches in 21 files
- 76.00% documented

### Added

- Carryover important fields from the original gemspec during templating
  - refactor gemspec parsing
  - normalize template gemspec data

### Fixed

- include FUNDING.md in the released gem package
- typo of required_ruby_version

## [1.0.22] - 2025-08-30

- TAG: [v1.0.22][1.0.22t]
- COVERAGE: 97.82% -- 2375/2428 lines in 20 files
- BRANCH COVERAGE: 81.34% -- 972/1195 branches in 20 files
- 76.23% documented

### Added

- improved documentation
- example version of heads workflow
  - give heads two attempts to succeed

## [1.0.21] - 2025-08-30

- TAG: [v1.0.21][1.0.21t]
- COVERAGE: 97.82% -- 2375/2428 lines in 20 files
- BRANCH COVERAGE: 81.34% -- 972/1195 branches in 20 files
- 76.23% documented

### Added

- FUNDING.md in support of a funding footer on release notes
  - <!-- RELEASE-NOTES-FOOTER-START -->
  - <!-- RELEASE-NOTES-FOOTER-END -->
- truffle workflow: Repeat attempts for bundle install and appraisal bundle before failure
- global token replacement during kettle:dev:install
  - kettle-dev => kettle-dev
  - {RUBOCOP|LTS|CONSTRAINT} => dynamic
  - {RUBOCOP|RUBY|GEM} => dynamic
  - default to rubocop-ruby1_8 if no minimum ruby specified
- template supports local development of RuboCop-LTS suite of gems
- improved documentation

### Changed

- dependabot: ignore rubocop-lts for updates
- template configures RSpec to run tests in random order

## [1.0.20] - 2025-08-29

- TAG: [v1.0.20][1.0.20t]
- COVERAGE: 14.01% -- 96/685 lines in 8 files
- BRANCH COVERAGE: 0.30% -- 1/338 branches in 8 files
- 76.23% documented

### Changed

- Use example version of ancient.yml workflow since local version has been customized
- Use example version of jruby.yml workflow since local version has been customized

## [1.0.19] - 2025-08-29

- TAG: [v1.0.19][1.0.19t]
- COVERAGE: 97.84% -- 2350/2402 lines in 20 files
- BRANCH COVERAGE: 81.46% -- 962/1181 branches in 20 files
- 76.23% documented

### Fixed

- replacement logic handles a dashed gem-name which maps onto a nested path structure

## [1.0.18] - 2025-08-29

- TAG: [v1.0.18][1.0.18t]
- COVERAGE: 71.70% -- 456/636 lines in 9 files
- BRANCH COVERAGE: 51.17% -- 153/299 branches in 9 files
- 76.23% documented

### Added

- kettle:dev:install can overwrite gemspec with example gemspec
- documentation for the start_step CLI option for kettle-release
- kettle:dev:install and kettle:dev:template support `only=` option with glob filtering:
  - comma-separated glob patterns matched against destination paths relative to project root
  - non-matching files are excluded from templating.

### Fixed

- kettle:dev:install remove "Works with MRI Ruby\*" lines with no badges left
- kettle:dev:install prefix badge cell replacement with a single space

## [1.0.17] - 2025-08-29

- TAG: [v1.0.17][1.0.17t]
- COVERAGE: 98.14% -- 2271/2314 lines in 20 files
- BRANCH COVERAGE: 81.42% -- 916/1125 branches in 20 files
- 76.23% documented

### Fixed

- kettle-changelog added to exe files so packaged with released gem

## [1.0.16] - 2025-08-29

- TAG: [v1.0.16][1.0.16t]
- COVERAGE: 98.14% -- 2271/2314 lines in 20 files
- BRANCH COVERAGE: 81.42% -- 916/1125 branches in 20 files
- 76.23% documented

### Fixed

- default rake task must be defined before it can be enhanced

## [1.0.15] - 2025-08-29

- TAG: [v1.0.15][1.0.15t]
- COVERAGE: 98.17% -- 2259/2301 lines in 20 files
- BRANCH COVERAGE: 81.00% -- 908/1121 branches in 20 files
- 76.03% documented

### Added

- kettle-release: early validation of identical set of copyright years in README.md and CHANGELOG.md, adds current year if missing, aborts on mismatch
- kettle-release: update KLOC in README.md
- kettle-release: update Rakefile.example with version and date

### Changed

- kettle-release: print package name and version released as final line
- use git adapter to wrap more git commands to make tests easier to build
- stop testing Ruby 2.4 on CI due to a strange issue with VCR.
  - still testing Ruby 2.3

### Fixed

- include gemfiles/modular/\*gemfile.example with packaged gem
- CI workflow result polling logic revised:
  - includes a delay
  - scopes queries to specific commit SHA
  - prevents false failures from previous runs

## [1.0.14] - 2025-08-28

- TAG: [v1.0.14][1.0.14t]
- COVERAGE: 97.70% -- 2125/2175 lines in 20 files
- BRANCH COVERAGE: 78.77% -- 842/1069 branches in 20 files
- 76.03% documented

### Added

- kettle-release: Push tags to additional remotes after release

### Changed

- Improve .gitlab-ci.yml pipeline

### Fixed

- Removed README badges for unsupported old Ruby versions
- Minor inconsistencies in template files
- git added as a dependency to optional.gemfile instead of the example template

## [1.0.13] - 2025-08-28

- TAG: [v1.0.13][1.0.13t]
- COVERAGE: 41.94% -- 65/155 lines in 6 files
- BRANCH COVERAGE: 1.92% -- 1/52 branches in 6 files
- 76.03% documented

### Added

- kettle-release: Create GitHub release from tag & changelog entry

## [1.0.12] - 2025-08-28

- TAG: [v1.0.12][1.0.12t]
- COVERAGE: 97.80% -- 1957/2001 lines in 19 files
- BRANCH COVERAGE: 79.98% -- 763/954 branches in 19 files
- 78.70% documented

### Added

- CIMonitor to consolidate workflow / pipeline monitoring logic for GH/GL across kettle-release and rake tasks, with handling for:
  - minutes exhausted
  - blocked
  - not configured
  - normal failures
  - pending
  - queued
  - running
  - success
- Ability to restart kettle-release from any failed step, so manual fixed can be applied.
  - Example (after intermittent failure of CI): `bundle exec kettle-release start_step=10`

### Fixed

- added optional.gemfile.example, and handling for it in templating
- kettle-changelog: ensure a blank line at end of file
- add sleep(0.2) to ci:act to prevent race condition with stdout flushing
- kettle-release: ensure SKIP_GEM_SIGNING works as expected with values of "true" or "false"
  - ensure it doesn't abort the process in CI

## [1.0.11] - 2025-08-28

- TAG: [v1.0.11][1.0.11t]
- COVERAGE: 97.90% -- 1959/2001 lines in 19 files
- BRANCH COVERAGE: 79.98% -- 763/954 branches in 19 files
- 78.70% documented

### Added

- Add more .example templates
  - .github/workflows/coverage.yml.example
  - .gitlab-ci.yml.example
  - Appraisals.example
- Kettle::Dev::InputAdapter: Input indirection layer for safe interactive prompts in tests; provides gets and readline; documented with YARD and typed with RBS.
- install task README improvements
  - extracts emoji grapheme from H1 to apply to gemspec's summary and description
  - removes badges for unsupported rubies, and major version MRI row if all badges removed
- new exe script: kettle-changelog - transitions a changelog from unreleased to next release

### Changed

- Make 'git' gem dependency optional; fall back to raw `git` commands when the gem is not present (rescues LoadError). See Kettle::Dev::GitAdapter.
- upgraded to stone_checksums v1.0.2
- exe scripts now print their name and version as they start up

### Removed

- dependency on git gem
  - git gem is still supported if present and not bypassed by new ENV variable `KETTLE_DEV_DISABLE_GIT_GEM`
  - no longer a direct dependency

### Fixed

- Upgrade stone_checksums for release compatibility with bundler v2.7+
  - Retains compatibility with older bundler < v2.7
- Ship all example templates with gem
- install task README preservation
  - preserves H1 line, and specific H2 headed sections
  - preserve table alignment

## [1.0.10] - 2025-08-24

- TAG: [v1.0.10][1.0.10t]
- COVERAGE: 97.68% -- 1685/1725 lines in 17 files
- BRANCH COVERAGE: 77.54% -- 618/797 branches in 17 files
- 95.35% documented

### Added

- runs git add --all before git commit, to ensure all files are committed.

### Changed

- This gem is now loaded via Ruby's standard `autoload` feature.
- Bundler is always expected, and most things probably won't work without it.
- exe/ scripts and rake tasks logic is all now moved into classes for testability, and is nearly fully covered by tests.
- New Kettle::Dev::GitAdapter class is an adapter pattern wrapper for git commands
- New Kettle::Dev::ExitAdapter class is an adapter pattern wrapper for Kernel.exit and Kernel.abort within this codebase.

### Removed

- attempts to make exe/\* scripts work without bundler. Bundler is required.

### Fixed

- `Kettle::Dev::ReleaseCLI#detect_version` handles gems with multiple VERSION constants
- `kettle:dev:template` task was fixed to copy `.example` files with the destination filename lacking the `.example` extension, except for `.env.local.example`

## [1.0.9] - 2025-08-24

- TAG: [v1.0.9][1.0.9t]
- COVERAGE: 100.00% -- 130/130 lines in 7 files
- BRANCH COVERAGE: 96.00% -- 48/50 branches in 7 files
- 95.35% documented

### Added

- kettle-release: Add a sanity check for the latest released version of the gem being released, and display it during the confirmation with user that CHANGELOG.md and version.rb have been updated, so they can compare the value in version.rb with the value of the latest released version.
  - If the value in version.rb is less than the latest released version's major or minor, then check for the latest released version that matches the major + minor of what is in version.rb.
  - This way a stable branch intended to release patch updates to older versions is able to work use the script.
- kettle-release: optional pre-push local CI run using `act`, controlled by env var `K_RELEASE_LOCAL_CI` ("true" to run, "ask" to prompt) and `K_RELEASE_LOCAL_CI_WORKFLOW` to choose a workflow; defaults to `locked_deps.yml` when present; on failure, soft-resets the release prep commit and aborts.
- template task: now copies `certs/pboling.pem` into the host project when available.

## [1.0.8] - 2025-08-24

- TAG: [v1.0.8][1.0.8t]
- COVERAGE: 100.00% -- 130/130 lines in 7 files
- BRANCH COVERAGE: 96.00% -- 48/50 branches in 7 files
- 95.35% documented

### Fixed

- Can't add checksums to the gem package, because it changes the checksum (duh!)

## [1.0.7] - 2025-08-24

- TAG: [v1.0.7][1.0.7t]
- COVERAGE: 100.00% -- 130/130 lines in 7 files
- BRANCH COVERAGE: 96.00% -- 48/50 branches in 7 files
- 95.35% documented

### Fixed

- Reproducible builds, with consistent checksums, by _not_ using SOURCE_DATE_EPOCH.
  - Since bundler v2.7.0 builds are reproducible by default.

## [1.0.6] - 2025-08-24

- TAG: [v1.0.6][1.0.6t]
- COVERAGE: 100.00% -- 130/130 lines in 7 files
- BRANCH COVERAGE: 96.00% -- 48/50 branches in 7 files
- 95.35% documented

### Fixed

- kettle-release: ensure SOURCE_DATE_EPOCH is applied within the same shell for both build and release by prefixing the commands with the env var (e.g., `SOURCE_DATE_EPOCH=$epoch bundle exec rake build` and `... rake release`); prevents losing the variable across shell boundaries and improves reproducible checksums.

## [1.0.5] - 2025-08-24

- TAG: [v1.0.5][1.0.5t]
- COVERAGE: 100.00% -- 130/130 lines in 7 files
- BRANCH COVERAGE: 96.00% -- 48/50 branches in 7 files
- 95.35% documented

### Fixed

- kettle-release: will run regardless of how it is invoked (i.e. works as binstub)

## [1.0.4] - 2025-08-24

- TAG: [v1.0.4][1.0.4t]
- COVERAGE: 100.00% -- 130/130 lines in 7 files
- BRANCH COVERAGE: 96.00% -- 48/50 branches in 7 files
- 95.35% documented

### Added

- kettle-release: checks all remotes for a GitHub remote and syncs origin/trunk with it; prompts to rebase or --no-ff merge when histories diverge; pushes to both origin and the GitHub remote on merge; uses the GitHub remote for GitHub Actions CI checks, and also checks GitLab CI when a GitLab remote and .gitlab-ci.yml are present.
- kettle-release: push logic improved — if a remote named `all` exists, push the current branch to it (assumed to cover multiple push URLs). Otherwise push the current branch to `origin` and to any GitHub, GitLab, and Codeberg remotes (whatever their names are).

### Fixed

- kettle-release now validates SHA256 checksums of the built gem against the recorded checksums and aborts on mismatch; helps ensure reproducible artifacts (honoring SOURCE_DATE_EPOCH).
- kettle-release now enforces CI checks and aborts if CI cannot be verified; supports GitHub Actions and GitLab pipelines, including releases from trunk/main.
- kettle-release no longer requires bundler/setup, preventing silent exits when invoked from a dependent project; adds robust output flushing.

## [1.0.3] - 2025-08-24

- TAG: [v1.0.3][1.0.3t]
- COVERAGE: 100.00% -- 98/98 lines in 7 files
- BRANCH COVERAGE: 100.00% -- 30/30 branches in 7 files
- 94.59% documented

### Added

- template task now copies .git-hooks files necessary for git hooks to work

### Fixed

- kettle-release now uses the host project's root, instead of this gem's installed root.
- Added .git-hooks files necessary for git hooks to work

## [1.0.2] - 2025-08-24

- TAG: [v1.0.2][1.0.2t]
- COVERAGE: 100.00% -- 98/98 lines in 7 files
- BRANCH COVERAGE: 100.00% -- 30/30 branches in 7 files
- 94.59% documented

### Fixed

- Added files necessary for kettle:dev:template task to work
- .github/workflows/opencollective.yml working!

## [1.0.1] - 2025-08-24

- TAG: [v1.0.1][1.0.1t]
- COVERAGE: 100.00% -- 98/98 lines in 7 files
- BRANCH COVERAGE: 100.00% -- 30/30 branches in 7 files
- 94.59% documented

### Added

- These were documented but not yet released:
  - `kettle-release` ruby script for safely, securely, releasing a gem.
    - This may move to its own gem in the future.
  - `kettle-readme-backers` ruby script for integrating Open Source Collective backers into a README.md file.
    - This may move to its own gem in the future.

## [1.0.0] - 2025-08-24

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 100.00% -- 98/98 lines in 7 files
- BRANCH COVERAGE: 100.00% -- 30/30 branches in 7 files
- 94.59% documented

### Added

- initial release, with auto-config support for:
  - bundler-audit
  - rake
  - require_bench
  - appraisal2
  - gitmoji-regex (& git-hooks to enforce gitmoji commit-style)
  - via kettle-test
    - Note: rake tasks for kettle-test are added in _this gem_ (kettle-dev) because test rake tasks are a development concern
    - rspec
      - although rspec is the focus, most tools work with minitest as well
    - rspec-block_is_expected
    - rspec-stubbed_env
    - silent_stream
    - timecop-rspec
- `kettle:dev:install` rake task for installing githooks, and various instructions for optimal configuration
- `kettle:dev:template` rake task for copying most of this gem's files (excepting bin/, docs/, exe/, sig/, lib/, specs/) to another gem, as a template.
- `ci:act` rake task CLI menu / scoreboard for a project's GHA workflows
  - Selecting will run the selected workflow via `act`
  - This may move to its own gem in the future.

[Unreleased]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.34...HEAD
[3.0.34]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.33...v3.0.34
[3.0.34t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.34
[3.0.33]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.32...v3.0.33
[3.0.33t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.33
[3.0.32]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.31...v3.0.32
[3.0.32t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.32
[3.0.31]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.30...v3.0.31
[3.0.31t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.31
[3.0.30]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.29...v3.0.30
[3.0.30t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.30
[3.0.29]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.28...v3.0.29
[3.0.29t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.29
[3.0.28]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.27...v3.0.28
[3.0.28t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.28
[3.0.27]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.26...v3.0.27
[3.0.27t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.27
[3.0.26]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.25...v3.0.26
[3.0.26t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.26
[3.0.25]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.24...v3.0.25
[3.0.25t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.25
[3.0.24]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.23...v3.0.24
[3.0.24t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.24
[3.0.23]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.22...v3.0.23
[3.0.23t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.23
[3.0.22]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.21...v3.0.22
[3.0.22t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.22
[3.0.21]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.20...v3.0.21
[3.0.21t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.21
[3.0.20]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.19...v3.0.20
[3.0.20t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.20
[3.0.19]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.18...v3.0.19
[3.0.19t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.19
[3.0.18]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.17...v3.0.18
[3.0.18t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.18
[3.0.17]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.16...v3.0.17
[3.0.17t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.17
[3.0.16]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.15...v3.0.16
[3.0.16t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.16
[3.0.15]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.14...v3.0.15
[3.0.15t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.15
[3.0.14]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.13...v3.0.14
[3.0.14t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.14
[3.0.13]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.12...v3.0.13
[3.0.13t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.13
[3.0.12]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.11...v3.0.12
[3.0.12t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.12
[3.0.11]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.10...v3.0.11
[3.0.11t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.11
[3.0.10]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.9...v3.0.10
[3.0.10t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.10
[3.0.9]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.8...v3.0.9
[3.0.9t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.9
[3.0.8]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.7...v3.0.8
[3.0.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.8
[3.0.7]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.6...v3.0.7
[3.0.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.7
[3.0.6]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.5...v3.0.6
[3.0.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.6
[3.0.5]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.4...v3.0.5
[3.0.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.5
[3.0.4]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.3...v3.0.4
[3.0.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.4
[3.0.3]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.2...v3.0.3
[3.0.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.3
[3.0.2]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.1...v3.0.2
[3.0.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.2
[3.0.1]: https://github.com/kettle-dev/kettle-dev/compare/v3.0.0...v3.0.1
[3.0.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.1
[3.0.0]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.28...v3.0.0
[3.0.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v3.0.0
[2.5.28]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.27...v2.5.28
[2.5.28t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.28
[2.5.27]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.26...v2.5.27
[2.5.27t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.27
[2.5.26]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.25...v2.5.26
[2.5.26t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.26
[2.5.25]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.24...v2.5.25
[2.5.25t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.25
[2.5.24]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.23...v2.5.24
[2.5.24t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.24
[2.5.23]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.22...v2.5.23
[2.5.23t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.23
[2.5.22]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.21...v2.5.22
[2.5.22t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.22
[2.5.21]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.20...v2.5.21
[2.5.21t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.21
[2.5.20]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.19...v2.5.20
[2.5.20t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.20
[2.5.19]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.18...v2.5.19
[2.5.19t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.19
[2.5.18]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.17...v2.5.18
[2.5.18t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.18
[2.5.17]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.16...v2.5.17
[2.5.17t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.17
[2.5.16]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.15...v2.5.16
[2.5.16t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.16
[2.5.15]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.14...v2.5.15
[2.5.15t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.15
[2.5.14]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.13...v2.5.14
[2.5.14t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.14
[2.5.13]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.12...v2.5.13
[2.5.13t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.13
[2.5.12]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.11...v2.5.12
[2.5.12t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.12
[2.5.11]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.10...v2.5.11
[2.5.11t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.11
[2.5.10]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.9...v2.5.10
[2.5.10t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.10
[2.5.9]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.8...v2.5.9
[2.5.9t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.9
[2.5.8]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.7...v2.5.8
[2.5.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.8
[2.5.7]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.6...v2.5.7
[2.5.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.7
[2.5.6]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.5...v2.5.6
[2.5.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.6
[2.5.5]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.4...v2.5.5
[2.5.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.5
[2.5.4]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.3...v2.5.4
[2.5.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.4
[2.5.3]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.2...v2.5.3
[2.5.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.3
[2.5.2]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.1...v2.5.2
[2.5.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.2
[2.5.1]: https://github.com/kettle-dev/kettle-dev/compare/v2.5.0...v2.5.1
[2.5.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.1
[2.5.0]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.6...v2.5.0
[2.5.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.5.0
[2.4.6]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.5...v2.4.6
[2.4.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.6
[2.4.5]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.4...v2.4.5
[2.4.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.5
[2.4.4]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.3...v2.4.4
[2.4.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.4
[2.4.3]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.2...v2.4.3
[2.4.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.3
[2.4.2]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.1...v2.4.2
[2.4.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.2
[2.4.1]: https://github.com/kettle-dev/kettle-dev/compare/v2.4.0...v2.4.1
[2.4.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.1
[2.4.0]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.11...v2.4.0
[2.4.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.4.0
[2.3.11]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.10...v2.3.11
[2.3.11t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.11
[2.3.10]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.9...v2.3.10
[2.3.10t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.10
[2.3.9]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.8...v2.3.9
[2.3.9t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.9
[2.3.8]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.7...v2.3.8
[2.3.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.8
[2.3.7]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.6...v2.3.7
[2.3.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.7
[2.3.6]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.5...v2.3.6
[2.3.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.6
[2.3.5]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.4...v2.3.5
[2.3.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.5
[2.3.4]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.3...v2.3.4
[2.3.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.4
[2.3.3]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.2...v2.3.3
[2.3.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.3
[2.3.2]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.1...v2.3.2
[2.3.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.2
[2.3.1]: https://github.com/kettle-dev/kettle-dev/compare/v2.3.0...v2.3.1
[2.3.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.1
[2.3.0]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.25...v2.3.0
[2.3.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.3.0
[2.2.25]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.24...v2.2.25
[2.2.25t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.25
[2.2.24]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.23...v2.2.24
[2.2.24t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.24
[2.2.23]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.22...v2.2.23
[2.2.23t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.23
[2.2.22]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.21...v2.2.22
[2.2.22t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.22
[2.2.21]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.20...v2.2.21
[2.2.21t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.21
[2.2.20]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.19...v2.2.20
[2.2.20t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.20
[2.2.19]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.18...v2.2.19
[2.2.19t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.19
[2.2.18]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.17...v2.2.18
[2.2.18t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.18
[2.2.17]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.16...v2.2.17
[2.2.17t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.17
[2.2.16]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.15...v2.2.16
[2.2.16t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.16
[2.2.15]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.14...v2.2.15
[2.2.15t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.15
[2.2.14]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.13...v2.2.14
[2.2.14t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.14
[2.2.13]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.12...v2.2.13
[2.2.13t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.13
[2.2.12]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.11...v2.2.12
[2.2.12t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.12
[2.2.11]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.10...v2.2.11
[2.2.11t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.11
[2.2.10]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.9...v2.2.10
[2.2.10t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.10
[2.2.9]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.8...v2.2.9
[2.2.9t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.9
[2.2.8]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.7...v2.2.8
[2.2.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.8
[2.2.7]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.6...v2.2.7
[2.2.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.7
[2.2.6]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.5...v2.2.6
[2.2.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.6
[2.2.5]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.4...v2.2.5
[2.2.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.5
[2.2.4]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.3...v2.2.4
[2.2.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.4
[2.2.3]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.2...v2.2.3
[2.2.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.3
[2.2.2]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.1...v2.2.2
[2.2.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.2
[2.2.1]: https://github.com/kettle-dev/kettle-dev/compare/v2.2.0...v2.2.1
[2.2.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.1
[2.2.0]: https://github.com/kettle-dev/kettle-dev/compare/v2.1.1...v2.2.0
[2.2.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.2.0
[2.1.1]: https://github.com/kettle-dev/kettle-dev/compare/v2.1.0...v2.1.1
[2.1.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.1.1
[2.1.0]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.8...v2.1.0
[2.1.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.1.0
[2.0.8]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.7...v2.0.8
[2.0.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.8
[2.0.7]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.6...v2.0.7
[2.0.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.7
[2.0.6]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.5...v2.0.6
[2.0.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.6
[2.0.5]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.4...v2.0.5
[2.0.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.5
[2.0.4]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.3...v2.0.4
[2.0.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.4
[2.0.3]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.2...v2.0.3
[2.0.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.3
[2.0.2]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.1...v2.0.2
[2.0.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.2
[2.0.1]: https://github.com/kettle-dev/kettle-dev/compare/v2.0.0...v2.0.1
[2.0.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.1
[2.0.0]: https://github.com/kettle-dev/kettle-dev/compare/v1.2.5...v2.0.0
[2.0.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v2.0.0
[1.2.5]: https://github.com/kettle-dev/kettle-dev/compare/v1.2.4...v1.2.5
[1.2.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.2.5
[1.2.4]: https://github.com/kettle-dev/kettle-dev/compare/v1.2.3...v1.2.4
[1.2.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.2.4
[1.2.3]: https://github.com/kettle-dev/kettle-dev/compare/v1.2.2...v1.2.3
[1.2.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.2.3
[1.2.2]: https://github.com/kettle-dev/kettle-dev/compare/v1.2.1...v1.2.2
[1.2.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.2.2
[1.2.0]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.60...v1.2.0
[1.2.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.2.0
[1.1.60]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.59...v1.1.60
[1.1.60t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.60
[1.1.59]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.58...v1.1.59
[1.1.59t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.59
[1.1.58]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.57...v1.1.58
[1.1.58t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.58
[1.1.57]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.56...v1.1.57
[1.1.57t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.57
[1.1.56]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.55...v1.1.56
[1.1.56t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.56
[1.1.55]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.54...v1.1.55
[1.1.55t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.55
[1.1.54]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.53...v1.1.54
[1.1.54t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.54
[1.1.53]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.52...v1.1.53
[1.1.53t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.53
[1.1.52]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.51...v1.1.52
[1.1.52t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.52
[1.1.51]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.50...v1.1.51
[1.1.51t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.51
[1.1.50]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.49...v1.1.50
[1.1.50t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.50
[1.1.49]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.48...v1.1.49
[1.1.49t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.49
[1.1.48]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.47...v1.1.48
[1.1.48t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.48
[1.1.47]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.46...v1.1.47
[1.1.47t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.47
[1.1.46]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.45...v1.1.46
[1.1.46t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.46
[1.1.45]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.44...v1.1.45
[1.1.45t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.45
[1.1.44]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.43...v1.1.44
[1.1.44t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.44
[1.1.43]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.42...v1.1.43
[1.1.43t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.43
[1.1.42]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.41...v1.1.42
[1.1.42t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.42
[1.1.41]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.40...v1.1.41
[1.1.41t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.41
[1.1.40]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.39...v1.1.40
[1.1.40t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.40
[1.1.39]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.38...v1.1.39
[1.1.39t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.39
[1.1.38]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.37...v1.1.38
[1.1.38t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.38
[1.1.37]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.36...v1.1.37
[1.1.37t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.37
[1.1.36]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.35...v1.1.36
[1.1.36t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.36
[1.1.35]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.34...v1.1.35
[1.1.35t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.35
[1.1.34]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.33...v1.1.34
[1.1.34t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.34
[1.1.33]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.32...v1.1.33
[1.1.33t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.33
[1.1.32]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.31...v1.1.32
[1.1.32t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.32
[1.1.31]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.30...v1.1.31
[1.1.31t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.31
[1.1.30]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.29...v1.1.30
[1.1.30t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.30
[1.1.29]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.28...v1.1.29
[1.1.29t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.29
[1.1.28]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.27...v1.1.28
[1.1.28t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.28
[1.1.27]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.25...v1.1.27
[1.1.27t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.27
[1.1.26]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.25...v1.1.26
[1.1.26t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.26
[1.1.25]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.24...v1.1.25
[1.1.25t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.25
[1.1.24]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.23...v1.1.24
[1.1.24t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.24
[1.1.23]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.22...v1.1.23
[1.1.23t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.23
[1.1.22]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.21...v1.1.22
[1.1.22t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.22
[1.1.21]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.20...v1.1.21
[1.1.21t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.21
[1.1.20]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.19...v1.1.20
[1.1.20t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.20
[1.1.19]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.18...v1.1.19
[1.1.19t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.19
[1.1.18]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.17...v1.1.18
[1.1.18t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.18
[1.1.17]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.16...v1.1.17
[1.1.17t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.17
[1.1.16]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.15...v1.1.16
[1.1.16t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.16
[1.1.15]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.14...v1.1.15
[1.1.15t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.15
[1.1.14]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.13...v1.1.14
[1.1.14t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.14
[1.1.13]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.12...v1.1.13
[1.1.13t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.13
[1.1.12]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.11...v1.1.12
[1.1.12t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.12
[1.1.11]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.10...v1.1.11
[1.1.11t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.11
[1.1.10]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.9...v1.1.10
[1.1.10t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.10
[1.1.9]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.8...v1.1.9
[1.1.9t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.9
[1.1.8]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.7...v1.1.8
[1.1.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.8
[1.1.7]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.6...v1.1.7
[1.1.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.7
[1.1.6]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.5...v1.1.6
[1.1.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.6
[1.1.5]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.4...v1.1.5
[1.1.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.5
[1.1.4]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.3...v1.1.4
[1.1.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.4
[1.1.3]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.2...v1.1.3
[1.1.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.3
[1.1.2]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.1...v1.1.2
[1.1.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.2
[1.1.1]: https://github.com/kettle-dev/kettle-dev/compare/v1.1.0...v1.1.1
[1.1.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.1
[1.1.0]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.27...v1.1.0
[1.1.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.1.0
[1.0.27]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.26...v1.0.27
[1.0.27t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.27
[1.0.26]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.25...v1.0.26
[1.0.26t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.26
[1.0.25]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.24...v1.0.25
[1.0.25t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.25
[1.0.24]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.23...v1.0.24
[1.0.24t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.24
[1.0.23]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.22...v1.0.23
[1.0.23t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.23
[1.0.22]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.21...v1.0.22
[1.0.22t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.22
[1.0.21]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.20...v1.0.21
[1.0.21t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.21
[1.0.20]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.19...v1.0.20
[1.0.20t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.20
[1.0.19]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.18...v1.0.19
[1.0.19t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.19
[1.0.18]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.17...v1.0.18
[1.0.18t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.18
[1.0.17]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.16...v1.0.17
[1.0.17t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.17
[1.0.16]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.15...v1.0.16
[1.0.16t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.16
[1.0.15]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.14...v1.0.15
[1.0.15t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.15
[1.0.14]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.13...v1.0.14
[1.0.14t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.14
[1.0.13]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.12...v1.0.13
[1.0.13t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.13
[1.0.12]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.11...v1.0.12
[1.0.12t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.12
[1.0.11]: https://github.com/kettle-dev/kettle-dev/compare/v1.0.10...v1.0.11
[1.0.11t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.11
[1.0.10]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.9...v1.0.10
[1.0.10t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.10
[1.0.9]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.8...v1.0.9
[1.0.9t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.9
[1.0.8]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.7...v1.0.8
[1.0.8t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.8
[1.0.7]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.6...v1.0.7
[1.0.7t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.7
[1.0.6]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.5...v1.0.6
[1.0.6t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.6
[1.0.5]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.4...v1.0.5
[1.0.5t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.5
[1.0.4]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.3...v1.0.4
[1.0.4t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.4
[1.0.3]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.2...v1.0.3
[1.0.3t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.3
[1.0.2]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.1...v1.0.2
[1.0.2t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.2
[1.0.1]: https://gitlab.com/kettle-dev/kettle-dev/-/compare/v1.0.0...v1.0.1
[1.0.1t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.1
[1.0.0]: https://github.com/kettle-dev/kettle-dev/compare/a427c302df09cfe4253a7c8d400333f9a4c1a208...v1.0.0
[1.0.0t]: https://github.com/kettle-dev/kettle-dev/releases/tag/v1.0.0
