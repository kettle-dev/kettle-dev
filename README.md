<a href="https://github.com/kettle-dev"><img alt="kettle-dev Logo by GitHub" src="https://github.com/kettle-dev.png?size=192" width="14%" align="right"/></a>

# 🍲 Kettle::Dev

[![Version][👽versioni]][👽version] [![Ruby Users Forum][✉️ruby-forum-top-img]][✉️ruby-forum] [![GitHub tag (latest SemVer)][⛳️tag-img]][⛳️tag] [![License: AGPL-3.0-only][📄license-img]][📄license] [![Total downloads][👽dl-ranki]][👽dl-rank] [![CodeCov Test Coverage][🏀codecovi]][🏀codecov] [![Coveralls Test Coverage][🏀coveralls-img]][🏀coveralls] [![QLTY Test Coverage][🏀qlty-covi]][🏀qlty-cov] [![QLTY Maintainability][🏀qlty-mnti]][🏀qlty-mnt] [![CI Heads][🚎3-hd-wfi]][🚎3-hd-wf] [![CI Runtime Dependencies @ HEAD][🚎12-crh-wfi]][🚎12-crh-wf] [![CI Current][🚎11-c-wfi]][🚎11-c-wf] [![CI Truffle Ruby][🚎9-t-wfi]][🚎9-t-wf] [![CI JRuby][🚎10-j-wfi]][🚎10-j-wf] [![Deps Locked][🚎13-🔒️-wfi]][🚎13-🔒️-wf] [![Deps Unlocked][🚎14-🔓️-wfi]][🚎14-🔓️-wf] [![CI Test Coverage][🚎2-cov-wfi]][🚎2-cov-wf] [![CI Style][🚎5-st-wfi]][🚎5-st-wf]

`if ci_badges.map(&:color).detect { it != "green"}` ☝️ [let me know on Discord][✉️discord-invite] or [RubyForum][✉️ruby-forum], as I may have missed the notification.

---

`if ci_badges.map(&:color).all? { it == "green"}` 👇️ send money so I can do more of this. FLOSS maintenance is now my full-time job.

[![OpenCollective Backers][🖇osc-backers-i]][🖇osc-backers] [![OpenCollective Sponsors][🖇osc-sponsors-i]][🖇osc-sponsors] [![Sponsor Me on Github][🖇sponsor-img]][🖇sponsor] [![Liberapay Goal Progress][⛳liberapay-img]][⛳liberapay] [![Donate on PayPal][🖇paypal-img]][🖇paypal] [![Buy me a coffee][🖇buyme-small-img]][🖇buyme] [![Donate at ko-fi.com][🖇kofi-img]][🖇kofi]

<details markdown="1">
 <summary>👣 How will this project approach the September 2025 hostile takeover of RubyGems? 🚑️</summary>

I've summarized my thoughts in [this blog post](https://dev.to/galtzo/hostile-takeover-of-rubygems-my-thoughts-5hlo).

</details>

## 🌻 Synopsis <a href="https://discord.gg/3qme4XHNKN"><img alt="Galtzo FLOSS Logo by Aboling0, CC BY-SA 4.0" src="https://logos.galtzo.com/assets/images/galtzo-floss/avatar-128px.svg" width="8%" align="right"/></a> <a href="https://ruby-toolbox.com"><img alt="ruby-lang Logo, Yukihiro Matsumoto, Ruby Visual Identity Team, CC BY-SA 2.5" src="https://logos.galtzo.com/assets/images/ruby-lang/avatar-128px.svg" width="8%" align="right"/></a>

Kettle::Dev is the development, CI, changelog, and release harness used by
kettle-dev gems. It installs rake tasks when loaded from a project's `Rakefile`,
and it ships command-line tools for changelog preparation, release automation,
multi-forge git remotes, commit-message hooks, and Open Collective README
updates.

Add it to a gem's development dependencies, then load the rake integration:

```ruby
# Gemfile
group :development, :test do
  gem "kettle-dev", require: false
end
```

```ruby
# Rakefile
require "kettle/dev"
```

For RSpec projects, use the matching test harness from
[kettle-test](https://github.com/kettle-dev/kettle-test):

```ruby
require "kettle/test/rspec"
```

Project setup and template refreshes are now owned by
[kettle-jem](https://github.com/kettle-dev/kettle-jem), not kettle-dev:

```console
gem install kettle-jem
kettle-jem setup
```

Once a project is wired, the normal local development loop is:

```console
bin/rake
bin/rake rubocop_gradual:autocorrect
bin/rake yard
```

And the maintainer release flow is:

```console
bin/kettle-pre-release
bin/kettle-changelog
bin/kettle-release
```

Family-wide releases are coordinated by the separate
[kettle-family](https://github.com/kettle-dev/kettle-family) gem, which shells
out to `kettle-release` for each member that needs publishing.

### What kettle-dev provides

- Rake task loading from `require "kettle/dev"`.
- RuboCop Gradual, Reek, YARD, appraisal, local CI, benchmark, and coverage task wiring.
- `kettle-changelog` for moving Unreleased changelog notes into a versioned release section with coverage and documentation stats.
- `kettle-release` for the canonical kettle-dev release flow.
- `kettle-pre-release` for release readiness checks.
- `kettle-dvcs` for normalizing GitHub, GitLab, Codeberg, and aggregate remotes.
- `kettle-commit-msg` for shared commit-message hook behavior.
- `kettle-readme-backers` for Open Collective README sections.
- `kettle-dev-setup` as a deprecated compatibility executable that exits with instructions to use kettle-jem.

## 💡 Info you can shake a stick at

| Tokens to Remember | [![Gem name][⛳️name-img]][⛳️gem-name] [![Gem namespace][⛳️namespace-img]][⛳️gem-namespace] |
|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Works with JRuby | [![JRuby 9.2 Compat][💎jruby-9.2i]][🚎jruby-9.2-wf] [![JRuby 9.3 Compat][💎jruby-9.3i]][🚎jruby-9.3-wf] <br/> [![JRuby 9.4 Compat][💎jruby-9.4i]][🚎jruby-9.4-wf] [![JRuby 10.0 Compat][💎jruby-10.0i]][🚎jruby-10.0-wf] [![JRuby current Compat][💎jruby-c-i]][🚎10-j-wf] [![JRuby HEAD Compat][💎jruby-headi]][🚎3-hd-wf]|
| Works with Truffle Ruby | [![Truffle Ruby 22.3 Compat][💎truby-22.3i]][🚎truby-22.3-wf] [![Truffle Ruby 23.0 Compat][💎truby-23.0i]][🚎truby-23.0-wf] [![Truffle Ruby 23.1 Compat][💎truby-23.1i]][🚎truby-23.1-wf] <br/> [![Truffle Ruby 24.2 Compat][💎truby-24.2i]][🚎truby-24.2-wf] [![Truffle Ruby 25.0 Compat][💎truby-25.0i]][🚎truby-25.0-wf] [![Truffle Ruby 33.0 Compat][💎truby-33.0i]][🚎truby-33.0-wf] [![Truffle Ruby current Compat][💎truby-c-i]][🚎9-t-wf] [![Truffle Ruby HEAD Compat][💎truby-headi]][🚎3-hd-wf]|
| Works with MRI Ruby 4 | [![Ruby current Compat][💎ruby-c-i]][🚎11-c-wf] [![Ruby HEAD Compat][💎ruby-headi]][🚎3-hd-wf]|
| Works with MRI Ruby 3 | [![Ruby 3.0 Compat][💎ruby-3.0i]][🚎ruby-3.0-wf] [![Ruby 3.1 Compat][💎ruby-3.1i]][🚎ruby-3.1-wf] [![Ruby 3.2 Compat][💎ruby-3.2i]][🚎ruby-3.2-wf] [![Ruby 3.3 Compat][💎ruby-3.3i]][🚎ruby-3.3-wf] [![Ruby 3.4 Compat][💎ruby-3.4i]][🚎ruby-3.4-wf]|
| Works with MRI Ruby 2 | [![Ruby 2.4 Compat][💎ruby-2.4i]][🚎ruby-2.4-wf] [![Ruby 2.5 Compat][💎ruby-2.5i]][🚎ruby-2.5-wf] [![Ruby 2.6 Compat][💎ruby-2.6i]][🚎ruby-2.6-wf] [![Ruby 2.7 Compat][💎ruby-2.7i]][🚎ruby-2.7-wf]|
| Support & Community | [![Join Me on Daily.dev's RubyFriends][✉️ruby-friends-img]][✉️ruby-friends] [![Get help from RubyForum][✉️ruby-forum-img]][✉️ruby-forum] [![Live Chat on Discord][✉️discord-invite-img-ftb]][✉️discord-invite] [![Get help from me on Upwork][👨🏼‍🏫expsup-upwork-img]][👨🏼‍🏫expsup-upwork] [![Get help from me on Codementor][👨🏼‍🏫expsup-codementor-img]][👨🏼‍🏫expsup-codementor] |
| Source | [![Source on GitLab.com][📜src-gl-img]][📜src-gl] [![Source on CodeBerg.org][📜src-cb-img]][📜src-cb] [![Source on GitHub.com][📜src-gh-img]][📜src-gh] [![The best SHA: dQw4w9WgXcQ!][🧮kloc-img]][🧮kloc] |
| Documentation | [![Current release on RubyDoc.info][📜docs-cr-rd-img]][🚎yard-current] [![YARD on Galtzo.com][📜docs-head-rd-img]][🚎yard-head] [![Maintainer Blog][🚂maint-blog-img]][🚂maint-blog] [![GitLab Wiki][📜gl-wiki-img]][📜gl-wiki] [![GitHub Wiki][📜gh-wiki-img]][📜gh-wiki] |
| Compliance | [![License: AGPL-3.0-only][📄license-img]][📄license] [![Apache license compatibility: Category X][📄license-compat-img]][📄license-compat] [![📄ilo-declaration-img]][📄ilo-declaration] [![Security Policy][🔐security-img]][🔐security] [![Contributor Covenant 2.1][🪇conduct-img]][🪇conduct] [![SemVer 2.0.0][📌semver-img]][📌semver] |
| Style | [![Enforced Code Style Linter][💎rlts-img]][💎rlts] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog] [![Gitmoji Commits][📌gitmoji-img]][📌gitmoji] [![Compatibility appraised by: appraisal2][💎appraisal2-img]][💎appraisal2] |
| Maintainer 🎖️ | [![Follow Me on LinkedIn][💖🖇linkedin-img]][💖🖇linkedin] [![Follow Me on Ruby.Social][💖🐘ruby-mast-img]][💖🐘ruby-mast] [![Follow Me on Bluesky][💖🦋bluesky-img]][💖🦋bluesky] [![Contact Maintainer][🚂maint-contact-img]][🚂maint-contact] [![My technical writing][💖💁🏼‍♂️devto-img]][💖💁🏼‍♂️devto] |
| `...` 💖 | [![Find Me on WellFound:][💖✌️wellfound-img]][💖✌️wellfound] [![Find Me on CrunchBase][💖💲crunchbase-img]][💖💲crunchbase] [![My LinkTree][💖🌳linktree-img]][💖🌳linktree] [![More About Me][💖💁🏼‍♂️aboutme-img]][💖💁🏼‍♂️aboutme] [🧊][💖🧊berg] [🐙][💖🐙hub] [🛖][💖🛖hut] [🧪][💖🧪lab] |

### Compatibility

Compatible with MRI Ruby 2.4.0+, JRuby, and TruffleRuby.
CI workflows and Appraisals are generated for MRI Ruby 2.4+.
This test floor is configured by `ruby.test_minimum` in `.kettle-jem.yml` and
may be higher than the gem's runtime compatibility floor when legacy Rubies are
not practical for the current toolchain.

<a href="https://github.com/kettle-dev"><img alt="kettle-dev Logo by Aboling0, CC BY-SA 4.0" src="https://logos.galtzo.com/assets/images/kettle-dev/avatar-128px.svg" width="14%" align="right"/></a>

The _amazing_ test matrix is powered by the kettle-dev stack.

<details markdown="1">
<summary>How kettle-dev manages complexity in tests</summary>

| Gem | Source | Role | Total downloads |
|-----|--------|------|---------------------|
| [appraisal2](https://clickgems.clickhouse.com/dashboard/appraisal2) | [GitHub](https://github.com/appraisal-rb/appraisal2) | multi-dependency Appraisal matrix generation | [![Total downloads for appraisal2](https://img.shields.io/gem/dt/appraisal2.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/appraisal2) |
| [appraisal2-rubocop](https://clickgems.clickhouse.com/dashboard/appraisal2-rubocop) | [GitHub](https://github.com/appraisal-rb/appraisal2-rubocop) | RuboCop Appraisal generator integration | [![Total downloads for appraisal2-rubocop](https://img.shields.io/gem/dt/appraisal2-rubocop.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/appraisal2-rubocop) |
| [kettle-jem](https://clickgems.clickhouse.com/dashboard/kettle-jem) | [GitHub](https://github.com/kettle-dev/kettle-jem) | Appraisals & CI workflow templates | [![Total downloads for kettle-jem](https://img.shields.io/gem/dt/kettle-jem.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-jem) |
| [kettle-soup-cover](https://clickgems.clickhouse.com/dashboard/kettle-soup-cover) | [GitHub](https://github.com/kettle-dev/kettle-soup-cover) | SimpleCov coverage policy and reporting | [![Total downloads for kettle-soup-cover](https://img.shields.io/gem/dt/kettle-soup-cover.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-soup-cover) |
| [kettle-test](https://clickgems.clickhouse.com/dashboard/kettle-test) | [GitHub](https://github.com/kettle-dev/kettle-test) | standard test runner and coverage harness | [![Total downloads for kettle-test](https://img.shields.io/gem/dt/kettle-test.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-test) |
| [rubocop-lts](https://clickgems.clickhouse.com/dashboard/rubocop-lts) | [GitHub](https://github.com/rubocop-lts/rubocop-lts) | Ruby-version-aware linting | [![Total downloads for rubocop-lts](https://img.shields.io/gem/dt/rubocop-lts.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/rubocop-lts) |
| [turbo_tests2](https://clickgems.clickhouse.com/dashboard/turbo_tests2) | [GitHub](https://github.com/galtzo-floss/turbo_tests2) | parallel test execution | [![Total downloads for turbo_tests2](https://img.shields.io/gem/dt/turbo_tests2.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/turbo_tests2) |

</details>

### Federated DVCS

<details markdown="1">
 <summary>Find this repo on federated forges (Coming soon!)</summary>

| Federated [DVCS][💎d-in-dvcs] Repository | Status | Issues | PRs | Wiki | CI |
|-------------------------------------------------|-------------------------------------------|-------------------|------------------|-----------------|----------------|
| 🧪 [kettle-dev/kettle-dev on GitLab][📜src-gl] | The Truth | [💚][🤝gl-issues] | [💚][🤝gl-pulls] | [💚][📜gl-wiki] | 🐭 Tiny Matrix |
| 🧊 [kettle-dev/kettle-dev on CodeBerg][📜src-cb] | An Ethical Mirror ([Donate][🤝cb-donate]) | [💚][🤝cb-issues] | [💚][🤝cb-pulls] | ➖ | ⭕️ No Matrix |
| 🐙 [kettle-dev/kettle-dev on GitHub][📜src-gh] | Another Mirror | [💚][🤝gh-issues] | [💚][🤝gh-pulls] | [💚][📜gh-wiki] | 💯 Full Matrix |

</details>

### Enterprise Support

[![Tidelift](https://tidelift.com/badges/package/rubygems/kettle-dev)](https://tidelift.com/subscription/pkg/rubygems-kettle-dev?utm_source=rubygems-kettle-dev&utm_medium=referral&utm_campaign=readme)

Available as part of the Tidelift Subscription.

<details markdown="1">
 <summary>Need enterprise-level guarantees?</summary>

The maintainers of this and thousands of other packages are working with Tidelift to deliver commercial support and maintenance for the open source packages you use to build your applications. Save time, reduce risk, and improve code health, while paying the maintainers of the exact packages you use.

[![Get help from me on Tidelift][🏙️entsup-tidelift-img]][🏙️entsup-tidelift]

- 💡Subscribe for support guarantees covering _all_ your FLOSS dependencies
- 💡Tidelift is part of [Sonar][🏙️entsup-tidelift-sonar]
- 💡Tidelift pays maintainers to maintain the software you depend on!<br/>📊`@`Pointy Haired Boss: An [enterprise support][🏙️entsup-tidelift] subscription is "[never gonna let you down][🧮kloc]", and *supports* open source maintainers

Alternatively:

- [![Ruby Users Forum][✉️ruby-forum-img]][✉️ruby-forum]
- [![Live Chat on Discord][✉️discord-invite-img-ftb]][✉️discord-invite]
- [![Get help from me on Upwork][👨🏼‍🏫expsup-upwork-img]][👨🏼‍🏫expsup-upwork]
- [![Get help from me on Codementor][👨🏼‍🏫expsup-codementor-img]][👨🏼‍🏫expsup-codementor]

</details>

## ✨ Installation

Install the gem and add to the application's Gemfile by executing:

```console
bundle add kettle-dev
```

If bundler is not being used to manage dependencies, install the gem by executing:

```console
gem install kettle-dev
```

## ⚙️ Configuration

Kettle-dev has two integration surfaces:

- Executable scripts in `exe/`, or binstubs generated from them, can run when
  `kettle-dev` is installed and loadable.
- Rake tasks are registered by adding `kettle-dev` to the project's development
  dependencies and requiring `kettle/dev` from the project's `Rakefile`.

```ruby
group :development, :test do
  gem "kettle-dev", require: false
end
```

```ruby
require "kettle/dev"
```

### RSpec

This gem integrates tightly with [kettle-test](https://github.com/kettle-dev/kettle-test).

```ruby
require "kettle/test/rspec"

# ... any other config you need to do.

# NOTE: Gemfiles for older rubies (< 2.7) won't have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  require "simplecov" if Kettle::Soup::Cover::DO_COV # `.simplecov` is run here!
rescue LoadError => error
  # check the error message, and re-raise if not what is expected
  raise error unless error.message.include?("kettle")
end

# This gem (or app)
require "gem-under-test"
```

### Rakefile

Add to your `Rakefile`:

```ruby
require "kettle/dev"
```

This loads the kettle-dev rake task set. Current project setup and template
refreshes should be run through kettle-jem:

```console
gem install kettle-jem
kettle-jem setup
```

`kettle-dev-setup` is still shipped for compatibility, but it now exits with a
message explaining that setup and templating moved to kettle-jem.

Useful registered tasks include:

- `rubocop_gradual:autocorrect` and `rubocop_gradual:check`
- `reek` and `reek:update`
- `yard`
- `appraisal:install`, `appraisal:generate`, `appraisal:update`, and `appraisal:reset`
- `ci:act`
- `bench`
- `kettle:jem:template` and `kettle:jem:selftest`, when kettle-jem's task integration is available

Install binstubs when a project wants local `bin/kettle-*` commands:

```console
bundle binstubs kettle-dev --path bin
```

### Environment Variables

Below are the primary environment variables recognized by kettle-dev (and its integrated tools). Unless otherwise noted, set boolean values to the string "true" to enable.

General/runtime

- `DEBUG`: Enable extra internal logging for this library (default: false)
- `REQUIRE_BENCH`: Enable `require_bench` to profile requires (default: false)
- `CI`: When set to true, adjusts default rake tasks toward CI behavior

Coverage (kettle-soup-cover / SimpleCov)

- `K_SOUP_COV_DO`: Enable coverage collection (default: true in .envrc)
- `K_SOUP_COV_FORMATTERS`: Comma-separated list of formatters (html, xml, rcov, lcov, json, tty)
- `K_SOUP_COV_MIN_LINE`: Minimum line coverage threshold (integer, e.g., 100)
- `K_SOUP_COV_MIN_BRANCH`: Minimum branch coverage threshold (integer, e.g., 100)
- `K_SOUP_COV_MIN_HARD`: Fail the run if thresholds are not met (true/false)
- `K_SOUP_COV_MULTI_FORMATTERS`: Enable multiple formatters at once (true/false)
- `K_SOUP_COV_OPEN_BIN`: Path to browser opener for HTML (empty disables auto-open)
- `MAX_ROWS`: Limit console output rows for simplecov-console (e.g., 1)

Tip: When running a single spec file locally, you may want `K_SOUP_COV_MIN_HARD=false` to avoid failing thresholds for a partial run.

GitHub API and CI helpers

- `GITHUB_TOKEN` or `GH_TOKEN`: Token used by `ci:act` and release workflow checks to query GitHub Actions status at higher rate limits
- `GITLAB_TOKEN` or `GL_TOKEN`: Token used by `ci:act` and CI monitor to query GitLab pipeline status

Releasing and signing

- `SKIP_GEM_SIGNING`: If set, skip gem signing during build/release
- `GEM_CERT_USER`: Username for selecting your public cert in `certs/<USER>.pem` (defaults to $USER)
- `SOURCE_DATE_EPOCH`: Reproducible build timestamp. `kettle-release` will set this automatically for the session.
- `KETTLE_RELEASE_SECRETS_PROVIDER`: Release secrets provider for direct
  `kettle-release` runs. Supported values are `interactive` and `1password`.
- `KETTLE_RELEASE_1PASSWORD_ITEM`: 1Password item for release secrets
  (default: `Rubygems`).
- `KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_FIELD`: 1Password field for
  the gem signing passphrase (default: `GEM-SIGN-PASSPHRASE`).
- `KETTLE_RELEASE_1PASSWORD_RUBYGEMS_OTP_FIELD`: 1Password OTP field for
  RubyGems MFA (default: `one-time password`).
- `KETTLE_RELEASE_1PASSWORD_ACCOUNT`: Optional 1Password account selector.
- `KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_REFERENCE` and
  `KETTLE_RELEASE_1PASSWORD_RUBYGEMS_OTP_REFERENCE`: Optional explicit
  `op://` references.

Family releases can load signing and RubyGems MFA secrets from 1Password via
`kettle-family` configuration instead of environment variables. See the
maintainer release section below.

Git hooks and commit message helpers (exe/kettle-commit-msg)

- `GIT_HOOK_BRANCH_VALIDATE`: Branch name validation mode (e.g., `jira`) or `false` to disable
- `GIT_HOOK_FOOTER_APPEND`: Append a footer to commit messages when goalie allows (true/false)
- `GIT_HOOK_FOOTER_SENTINEL`: Required when footer append is enabled — a unique first-line sentinel to prevent duplicates
- `GIT_HOOK_FOOTER_APPEND_DEBUG`: Extra debug output in the footer template (true/false)

For a quick starting point, this repository’s `.envrc` shows sane defaults, and `.env.local` can override them locally.

## 🔧 Basic Usage

Common local workflows:

- `bundle exec rake` runs the curated default task set. Locally this favors
  autocorrection where supported; with `CI=true` it favors check-only behavior.
- `bin/rspec` or `bundle exec rspec` runs specs.
- `K_SOUP_COV_MIN_HARD=false bin/rspec spec/path/to/file_spec.rb` is useful for
  focused spec runs that should not fail whole-suite coverage thresholds.
- `bundle exec rake rubocop_gradual:autocorrect` applies gradual RuboCop fixes.
- `bundle exec rake rubocop_gradual:check` is the CI-friendly RuboCop Gradual task.
- `bundle exec rake reek` and `bundle exec rake reek:update` run or refresh Reek.
- `bundle exec rake yard` builds API documentation.
- `bundle exec rake appraisal:install` performs first-time Appraisal setup.
- `bundle exec rake appraisal:generate` regenerates Appraisal gemfiles.
- `bundle exec rake appraisal:update` updates Appraisal locks and applies gradual RuboCop autocorrect.
- `bundle exec rake appraisal:reset` removes Appraisal lockfiles below `gemfiles/`.
- `kettle-bump patch` bumps the current gem's patch version before running
  `kettle-changelog`.

GitHub Actions local runner helper:

- `bundle exec rake ci:act` opens an interactive workflow selector using
  `.github/workflows` and live CI status when tokens are available.
- `bundle exec rake ci:act[loc]` selects by short code.
- `bundle exec rake ci:act[locked_deps.yml]` selects by workflow filename.
- Set `GITHUB_TOKEN` or `GH_TOKEN` for GitHub Actions API status.
- Set `GITLAB_TOKEN` or `GL_TOKEN` for GitLab pipeline status.

Project automation and template refreshes:

- Use `kettle-jem setup` for first-time setup and `kettle-jem install` for
  full template refreshes.
- When kettle-jem's rake integration is installed, run `bundle exec rake kettle:jem:template`
  to refresh template-managed files.
- `kettle-dev-setup` is deprecated and intentionally exits with a migration
  message pointing to kettle-jem.

### kettle-dvcs (normalize multi-forge remotes)

- Script: `exe/kettle-dvcs` (install binstubs for convenience: `bundle binstubs kettle-dev --path bin`)
- Purpose: Normalize git remotes across GitHub, GitLab, and Codeberg, and create an `all` remote that pushes to all and fetches only from your chosen origin.
- Assumptions: org and repo names are identical across forges.
  Usage:

<!-- end list -->

```console
kettle-dvcs [options] [ORG] [REPO]
```

Options:

- `--origin [github|gitlab|codeberg]` Which forge to use as `origin` (default: github)
- `--protocol [ssh|https]` URL style (default: ssh)
- `--github-name NAME` Remote name for GitHub when not origin (default: gh)
- `--gitlab-name NAME` Remote name for GitLab (default: gl)
- `--codeberg-name NAME` Remote name for Codeberg (default: cb)
- `--force` Non-interactive; accept defaults, and do not prompt for ORG/REPO
  Examples:
- Default, interactive (infers ORG/REPO from an existing remote when possible):
  ```console
  kettle-dvcs
  ```
- Non-interactive with explicit org/repo:
  ```console
  kettle-dvcs --force my-org my-repo
  ```
- Use GitLab as origin and HTTPS URLs:
  ```console
  kettle-dvcs --origin gitlab --protocol https my-org my-repo
  ```

What it does:

- Ensures remotes exist and have consistent URLs for each forge.
- Renames existing remotes when their URL already matches the desired target but their name does not (e.g., `gitlab` -\> `gl`).
- Creates/refreshes an `all` remote that:
    - fetches only from your chosen `origin` forge.
    - has pushurls configured for all three forges so `git push all <branch>` updates all mirrors.
- Prints `git remote -v` at the end.
- Attempts to `git fetch` each forge remote to check availability:
    - If all succeed, the README’s federated DVCS summary line has “(Coming soon\!)” removed.
    - If any fail, the script prints import links to help you create a mirror on that forge.

### Releasing (maintainers)

- Script: `exe/kettle-release` (run as `kettle-release`)
- Purpose: guided release helper that:
    - Runs `kettle-pre-release` as step 0 on full releases, aborting before release setup if any pre-release gate fails.
    - Validates Markdown reference definitions and local heading anchors across releasable documentation before network checks.
      Markdown fixtures under `spec/` and `test/`, along with `tmp/`, are intentionally excluded.
    - Skips pre-release checks for any `start_step` greater than `0`, so resumptions begin directly at the requested numbered step.
    - Verifies Bundler >= 2.7, updates the primary and appraisal bundles with `bundle update --bundler`, and commits those lockfiles separately as `🔒️ Update bundle` before release preparation.
    - Runs sanity checks (`bin/setup`, `bin/rake`), confirms version/changelog, optionally updates Appraisals, regenerates docs via `bin/rake yard`, and commits “🔖 Prepare release vX.Y.Z”. Use `--skip-appraisals` only to omit appraisal generation while retaining documentation generation.
    - Optionally runs your CI locally with `act` before any push:
        - Enable with env: `K_RELEASE_LOCAL_CI="true"` (run automatically) or `K_RELEASE_LOCAL_CI="ask"` (prompt \[Y/n\]).
        - Select workflow with `K_RELEASE_LOCAL_CI_WORKFLOW` (with or without .yml/.yaml). Defaults to `locked_deps.yml` if present; otherwise the first workflow discovered.
        - On failure, the release prep commit is soft-rolled-back (`git reset --soft HEAD^`) and the process aborts.
    - Ensures trunk sync and rebases feature as needed, pushes, monitors GitHub Actions with a progress bar, and merges feature to trunk on success.
    - Exports `SOURCE_DATE_EPOCH`, builds (optionally signed), creates gem checksums, and runs `bundle exec rake release` (prompts for signing key + RubyGems MFA OTP as needed).
- Options:
    - `start_step` map (skip directly to a phase):
        0.  Run `kettle-pre-release` gates
        1.  Verify Bundler \>= 2.7; update and commit the primary/appraisal Bundler lockfiles (start at 1 to skip pre-release checks)
        2.  Detect version; RubyGems sanity check; confirm CHANGELOG/version; sync copyright years; update badges/headers
        3.  Run bin/setup
        4.  Run bin/rake (default task)
        5.  Run bin/rake appraisal:generate if Appraisals are present, then bin/rake yard
            (or appraisal:update with --appraisal-update)
        6.  Ensure git user configured; commit release prep
        7.  Optional local CI with `act` (controlled by `K_RELEASE_LOCAL_CI`)
        8.  Ensure trunk in sync across remotes; rebase feature as needed
        9.  Push current branch to remotes (or 'all' remote)
        10. Monitor CI after push; abort on failures
        11. Merge feature into trunk and push
        12. Checkout trunk and pull latest
        13. Gem signing checks/guidance (skip with `SKIP_GEM_SIGNING=true`)
        14. Build gem (bundle exec rake build)
        15. Release gem (bundle exec rake release)
        16. Generate and validate checksums (`bin/gem_checksums`)
        17. Push checksum commit
        18. Create GitHub Release (requires `GITHUB_TOKEN`)
        19. Push tags to remotes (final)
- Examples:
    - After a transient CI or provider failure with no code, version, changelog, or lockfile changes, restart at the failed step: for example, `bundle exec kettle-release --start-step 10` for CI monitoring or `bundle exec kettle-release --start-step 15` for RubyGems publication. The legacy `start_step=10` spelling remains supported.
    - If the failure required a code or release-metadata change, rerun `bundle exec kettle-release` from step 0 so the release checks, prep metadata, commit, and CI all describe the new release commit.
    - For an intentional same-commit CI bypass, use `bundle exec kettle-release --skip-ci` (or `--skip-steps 10`); this skips remote CI monitoring only and does not claim that CI passed.
    - To retain release documentation generation while bypassing a known Appraisal-only issue, use `bundle exec kettle-release --skip-appraisals`.
    - After fixing a failed pre-release gate, rerun from step 0: `bundle exec kettle-release`
    - After intentionally handling a failed pre-release gate, skip it and start numbered release steps: `bundle exec kettle-release --start-step 1`
    - Auto-approve release confirmation prompts: `bundle exec kettle-release --yes`
    - Run direct release with 1Password secrets: `bundle exec kettle-release --secrets-provider 1password`
- Lockfile recovery:
    - Script: `exe/kettle-reset` (run as `kettle-reset`)
    - Reset a CI-facing lockfile after local development has written sibling
      paths or checksum-less local gem versions: `bundle exec kettle-reset Gemfile.lock`
    - Reset both release-facing lockfiles together:
      `bundle exec kettle-reset release-lockfiles`
    - Reset the appraisal root lockfile directly:
      `bundle exec kettle-reset Appraisal.root.gemfile.lock`
    - Validate without changing the lockfile: `bundle exec kettle-reset --check Gemfile.lock`
    - `kettle-reset` disables path-like `*_DEV` and `*_LOCAL` environment
      variables, known local-template toggles, and writes checksums while
      updating path-sourced and checksum-gap gems back to released registry
      versions.
    - Gemfile bootstrap dependencies are separate from dependency resolution.
      A generated Gemfile can require `nomono/bundler` while it is being
      evaluated, before Bundler has resolved its declared `nomono` gem.
      `kettle-reset` detects that literal bootstrap require and installs the
      locked registry version of `nomono` into its temporary `GEM_HOME` before
      invoking Bundler. Its `GEM_PATH` contains only that reset sandbox: no
      unrelated gems installed for the invoking Ruby can affect lockfile
      resolution.
    - Release lockfile resets normally keep the complete development Gemfile
      graph, including the development-only `kettle-changelog` dependency.
      `kettle-changelog` depends on `kettle-dev`, so including it in
      `kettle-dev`'s development bundle creates a downstream development-cycle
      when sibling versions are unpublished. The
      `--skip-changelog-dependency` (or the equivalent
      `KETTLE_DEV_SKIP_CHANGELOG_DEPENDENCY=true` Gemfile switch) is available
      for an explicit bootstrap/release graph that cannot resolve that
      downstream tool. It is intentionally not the default for standalone
      tracked development lockfiles.
    - At release step 1, `kettle-release` runs the equivalent of
      `kettle-family bupb`: it updates the primary lockfile and, when present,
      `Appraisal.root.gemfile.lock`, resets appraisal locks, and commits only
      those lockfiles as `🔒️ Update bundle`. This keeps Bundler maintenance in
      its own atomic commit. `kettle-changelog` writes changelog content but
      does not own this commit; the release helper commits release metadata
      separately.
    - Release-target resets also pass `bundle lock --bundler`, recording the
      Bundler that performed the final reset in each committed release
      lockfile. This keeps the normalized lockfile consistent with the
      Bundler used by the release.
    - During `kettle-release`, release lockfiles are reset before the release
      prep commit. Before pushing, `kettle-release` validates those committed
      lockfiles again; if local paths or checksum gaps reappear, it prints the
      diagnostics, attempts one reset, amends the release prep commit if the
      reset changed tracked lockfiles, and aborts if diagnostics remain.
    - Release build and publish tasks use a disposable copy of `Gemfile.lock`.
      This is intentional: `bundle lock --add-platform` records the normalized
      CI platforms, but it is not a permanent preservation directive. A later
      non-frozen `bundle exec rake build` or `bundle exec rake release` can
      reconcile the lockfile for the host platform and rewrite the tracked
      file. RubyGems' `bundler/gem_tasks` then sees that rewrite and aborts at
      its clean-tree guard, even though the release inputs were valid. The
      temporary `BUNDLE_LOCKFILE` lets Bundler perform that runtime
      reconciliation without changing the committed release lockfile; it is
      removed when the release process exits. `BUNDLE_FROZEN=true` is not a
      substitute because it converts the same reconciliation into a failure
      when Bundler needs to write its resolved lockfile.
    - Lockfile roles are explicit during a release:

      | Role | Lockfile | Used by |
      | --- | --- | --- |
      | Family runner | The family/orchestrator bundle | May resolve local sibling gems to run `kettle-family`; it never becomes the target project's lockfile. |
      | Canonical release state | Tracked `Gemfile.lock` and, when present, `Appraisal.root.gemfile.lock` | Step 1 Bundler update, steps 3-6 setup/checks/appraisals/docs/prep commit, and step 16 checksums. These commands disable local `*_DEV`/`*_LOCAL` switches, except an explicitly allowed monorepo member-root policy supplied by `kettle-family`. Reset `GEM_HOME` and `GEM_PATH` are isolated; direct Gemfile bootstrap requirements are installed from their locked registry source into that sandbox before Bundler evaluates the Gemfile. |
      | Release task state | `tmp/kettle-release/lockfiles/Gemfile-<pid>.lock` | Steps 14-15 build and publish only. It begins as a copy of canonical `Gemfile.lock` and is deleted at process exit. |
      | Tool state | A tool-owned Gemfile such as `kettle-changelog/gemfiles/release.gemfile` | The tool's own dependencies. The command still disables local dependency switches before it can trigger target-project work. |
      | Git-hook state | Canonical release environment | Every release-created commit and amend. Hooks remain enabled, but cannot inherit the family runner's local sibling graph. |

      A command must select one of these roles. Do not construct an ad hoc
      `BUNDLE_GEMFILE`, `BUNDLE_LOCKFILE`, or local-development environment in
      a release phase. `ReleaseCLI#release_child_command` owns canonical/tool
      command construction; `ReleaseCLI#release_project_command` selects the
      disposable task lock only for build and publish.

      The monorepo exception is intentionally narrow. `kettle-family` derives
      it only from `family.mode: monorepo` and its configured members root, then
      passes the allowed root and activating environment name to
      `kettle-release`. A sibling Kettle Dev checkout is not covered: normal
      releases must use the released `kettle-family`, `kettle-changelog`, and
      other Kettle dependencies. Local Kettle Dev integration is an explicit
      development opt-in, never a canonical release-lock default.
- Tips:
    - The commit message helper `exe/kettle-commit-msg` prefers project-local `.git-hooks` (then falls back to `~/.git-hooks`).
    - The goalie file `commit-subjects-goalie.txt` controls when a footer is appended; customize `footer-template.erb.txt` as you like.

Direct `kettle-release` runs can opt in to 1Password for the gem signing
passphrase and RubyGems MFA OTP:

```console
bundle exec kettle-release --secrets-provider 1password
```

The default 1Password lookup uses item `Rubygems`, field
`GEM-SIGN-PASSPHRASE` for the signing key passphrase, and the item's OTP for
RubyGems MFA. Override those values with the `KETTLE_RELEASE_1PASSWORD_*`
environment variables above. `kettle-release` fetches the OTP at prompt time so
long releases do not reuse a stale TOTP.

#### Family releases and 1Password

`kettle-release` owns the single-gem release flow. Family-wide release
orchestration depends on the separate
[kettle-family](https://github.com/kettle-dev/kettle-family) gem:
`kettle-family release` selects sibling or monorepo members and delegates each
publish step to `kettle-release`. For family releases, the usual publish
command is:

```console
kettle-family release --publish --execute
```

By default, `kettle-family` prompts once for the gem signing key password and
leaves RubyGems MFA prompts interactive. To run a family release with the local
1Password CLI, configure `release.secrets` in `.kettle-family.yml` and pass
`--secrets-provider 1password`:

```yaml
release:
  secrets:
    provider: 1password
    item: Rubygems
    gem_signing_passphrase_field: GEM-SIGN-PASSPHRASE
    rubygems_otp_field: one-time password
```

```console
kettle-family release --publish --execute --secrets-provider 1password
```

The gem signing passphrase is loaded once by `kettle-family` and handed to
child `kettle-release` processes through an internal environment integration so
1Password is not queried repeatedly for the same value. RubyGems OTP values are
fetched by `kettle-release` when each MFA prompt appears, so direct and family
releases share the same OTP behavior. Secret values are not written to the text
report, NDJSON events, or temporary release files.

For vault-specific or field-specific lookups, use explicit 1Password
references. `rubygems_otp_reference` is read with `op read`; otherwise the OTP
path uses `op item get ITEM --otp`.

```yaml
release:
  secrets:
    provider: 1password
    account: my.1password.com
    gem_signing_passphrase_reference: op://Private/Rubygems/GEM-SIGN-PASSPHRASE
    rubygems_otp_reference: op://Private/Rubygems/one-time password?attribute=otp
```

If an old failed family release left unpublished sibling versions installed
locally and Bundler keeps selecting them, clean them before retrying:

```console
kettle-family clean-unreleased --execute
```

The cleanup command is scoped to selected family members and removes local gem
versions that are newer than the latest released version.

### Changelog generator

- Script: `exe/kettle-bump` (run as `kettle-bump`)
- Purpose: Bumps the current single gem's `lib/**/version.rb` before changelog
  preparation. It accepts an exact version or `major`, `minor`, `patch`, or
  `pre`.
- Usage:
    - `kettle-bump patch`
    - `kettle-bump pre`
    - `kettle-bump 1.2.4 --from 1.2.3`
    - `kettle-bump minor --dry-run`
    - `kettle-bump patch --check`
- Behavior:
    - Writes by default; use `--dry-run` to preview or `--check` to fail when a
      bump would change files.
    - Updates literal `spec.version = "..."` assignments in the gemspec when
      they match the current version. Dynamic gemspec versions are left alone.
    - Uses the same `K_CHANGELOG_VERSION_FILE` override as `kettle-changelog`
      when a project needs to point at a specific version file.

- Script: `exe/kettle-changelog` (run as `kettle-changelog`)
- Purpose: Generates a new CHANGELOG.md section for the current version read from `lib/**/version.rb`, moves notes from the Unreleased section, and updates comparison links.
- Prerequisites:
    - `coverage/coverage.json` present (generate with: `K_SOUP_COV_FORMATTERS="json" bin/rspec`).
    - `bin/rake yard` available, to compute documentation coverage.
- Usage:
    - `kettle-changelog`
- Behavior:
    - Reads version from the unique `lib/**/version.rb` in the project.
    - Reads the gem name from the root `.gemspec`; set
      `K_CHANGELOG_GEM_NAME` when a root changelog represents a family instead
      of a single gem checkout.
    - Set `K_CHANGELOG_VERSION_FILE` when a root changelog should use a specific
      version file outside the default `lib/**/version.rb` discovery path.
    - Moves entries from the `[Unreleased]` section into a new `[#.#.#] - YYYY-MM-DD` section.
    - Prepends 4 lines with TAG, line coverage, branch coverage, and percent documented.
    - Converts any GitLab-style compare links at the bottom to GitHub style, adds new tag/compare links for the new release and a temporary tag reference `[X.Y.Zt]`.

### Pre-release checks

- Script: `exe/kettle-gha-sha-pins` (run as `kettle-gha-sha-pins`)
- New projects should install `kettle-gha-pins` and run `kettle-gha-pins`
  directly; this `kettle-dev` command remains as a compatibility wrapper.
- Purpose: Validate and optionally update GitHub Actions `uses:` refs to pinned
  SHAs and current allowed release versions.
- Usage:
    - `kettle-gha-sha-pins`
    - `kettle-gha-sha-pins --check`
    - `kettle-gha-sha-pins --write --upgrade patch`
- Behavior:
    - Human output shows discovery, workflow scan, and action-resolution progress
      on STDERR, including per-action timing via `ruby-progressbar`, then prints
      the final report on STDOUT.
    - Action metadata is resolved with the GitHub REST API and cached per
      `owner/repo` action so duplicate uses of the same action reuse one
      resolution plan.
    - The outdated summary reports newer releases even when `--upgrade patch` or
      `--upgrade minor` limits the write target to a safer release line.
    - JSON output keeps progress disabled by default so STDOUT remains parseable.
      Use `--progress` to force progress or `--no-progress` to suppress it.
    - `--check` exits non-zero when workflow action pins are stale or mutable and
      prints a recommended `kettle-gha-sha-pins --write --upgrade patch` command.

- Script: `exe/kettle-pre-release` (run as `kettle-pre-release`)
- Purpose: Run a suite of pre-release validations to catch avoidable mistakes (resumable by check number).
- Usage:
    - `kettle-pre-release [--check-num N]`
    - Short option: `kettle-pre-release -cN`
- Options:
    - `--check-num N` Start from check number N (default: 1)
- Checks:
    - 1) Validate GitHub Actions workflow action refs with `kettle-gha-sha-pins --check`; if pins are stale, it prints an outdated-actions summary, exits non-zero, and recommends `kettle-gha-sha-pins --write --upgrade patch`.
    - 2) Normalize Markdown image URLs.
    - 3) Validate Markdown references and local heading targets.
    - 4) Validate that all image URLs referenced by Markdown files resolve (HTTP HEAD).
- Image URL skips:
    - Star-history and contrib.rocks generated image URLs are skipped by default because they are volatile.
    - Unresolved Kettle-Jem template tokens are skipped because they are not URLs until templating completes.
    - Add project-specific shell-style URL patterns in `.kettle-family.yml` or a config path pointed to by `KETTLE_FAMILY_CONFIG`. `kettle-family` passes this path through when it orchestrates a member release, but `kettle-dev` owns the matching and validation:
        ```yaml
        pre_release:
          image_url_skip_patterns:
            - https://assets.example.com/generated/*
        ```

### Commit message helper (git hook)

- Script: `exe/kettle-commit-msg` (run by git as `.git/hooks/commit-msg`)
- Purpose: Append a standardized footer and optionally enforce branch naming rules when configured.
- Usage:
    - Git invokes this with the path to the commit message file: `kettle-commit-msg .git/COMMIT_EDITMSG`
    - Install hook templates through kettle-jem setup/templating, then point git at the resulting hook path.
- Behavior:
    - When `GIT_HOOK_BRANCH_VALIDATE=jira`, validates the current branch matches the pattern: `^(hotfix|bug|feature|candy)/[0-9]{8,}-…`.
        - If it matches and the commit message lacks the numeric ID, appends `[<type>][<id>]`.
    - Always invokes `Kettle::Dev::GitCommitFooter.render` to potentially append a footer if allowed by the goalie.
    - Prefers project-local `.git-hooks` templates; falls back to `~/.git-hooks`.
- Environment:
    - `GIT_HOOK_BRANCH_VALIDATE` Branch rule (e.g., `jira`) or `false` to disable.
    - `GIT_HOOK_FOOTER_APPEND` Enable footer auto-append when goalie allows (true/false).
    - `GIT_HOOK_FOOTER_SENTINEL` Required marker to avoid duplicate appends when enabled.
    - `GIT_HOOK_FOOTER_APPEND_DEBUG` Extra debug output in the footer template (true/false).

### Project bootstrap installer

- Script: `exe/kettle-dev-setup` (run as `kettle-dev-setup`)
- Status: Deprecated compatibility shim.
- Purpose: Direct users to kettle-jem, which now owns setup and templating.
- Usage:
    - `kettle-dev-setup`
- Behavior:
    - Prints migration instructions.
    - Exits non-zero.
    - Does not modify the destination repository.
- Replacement:
    - `gem install kettle-jem`
    - `kettle-jem setup`

### Open Collective README updater

- Script: `exe/kettle-readme-backers` (run as `kettle-readme-backers`)
- Purpose: Updates README sections for Open Collective backers (individuals) and sponsors (organizations) by fetching live data from your collective.
- Tags updated in README.md (first match wins for backers):
    - The default tag prefix is `OPENCOLLECTIVE`, and it is configurable:
        - ENV: `KETTLE_DEV_BACKER_README_OSC_TAG="OPENCOLLECTIVE"`
        - YAML (.opencollective.yml): `readme-osc-tag: "OPENCOLLECTIVE"`
        - The resulting markers become: `<!-- <TAG>:START --> … <!-- <TAG>:END -->`, `<!-- <TAG>-INDIVIDUALS:START --> … <!-- <TAG>-INDIVIDUALS:END -->`, and `<!-- <TAG>-ORGANIZATIONS:START --> … <!-- <TAG>-ORGANIZATIONS:END -->`.
        - ENV overrides YAML.
    - Backers (Individuals): `<!-- <TAG>:START --> … <!-- <TAG>:END -->` or `<!-- <TAG>-INDIVIDUALS:START --> … <!-- <TAG>-INDIVIDUALS:END -->`
    - Sponsors (Organizations): `<!-- <TAG>-ORGANIZATIONS:START --> … <!-- <TAG>-ORGANIZATIONS:END -->`
- Handle resolution:
    1.  `OPENCOLLECTIVE_HANDLE` environment variable, if set
    2.  `opencollective.yml` in the project root (e.g., `collective: "kettle-dev"` in this repo)
- Usage:
    - `exe/kettle-readme-backers`
    - `OPENCOLLECTIVE_HANDLE=my-collective exe/kettle-readme-backers`
- Behavior:
    - Writes to README.md only if content between the tags would change.
    - If neither the backers nor sponsors tags are present, prints a helpful warning and exits with status 2.
    - When there are no entries, inserts a friendly placeholder: "No backers yet. Be the first\!" or "No sponsors yet. Be the first\!".
    - When updates are written and the repository is a git work tree, the script stages README.md and commits with a message thanking new backers and subscribers, including mentions for any newly added backers and subscribers (GitHub @handles when their website/profile is a github.com URL; otherwise their name).
    - Customize the commit subject via env var: `KETTLE_README_BACKERS_COMMIT_SUBJECT="💸 Thanks 🙏 to our new backers 🎒 and subscribers 📜"`.
        - Or via .opencollective.yml: set `readme-backers-commit-subject: "💸 Thanks 🙏 to our new backers 🎒 and subscribers 📜"`.
        - Precedence: ENV overrides .opencollective.yml; if neither is set, a sensible default is used.
        - Note: When used with the provided `.git-hooks`, the subject should start with a gitmoji character (see [gitmoji][📌gitmoji]).
- Tip:
    - Run this locally before committing to keep your README current, or schedule it in CI to refresh periodically.
    - It runs automatically on a once-a-week schedule by the .github/workflows/opencollective.yml workflow that is part of the kettle-jem template.
- Authentication requirement:
    - When running in CI with the provided workflow, you must provide an organization-level Actions secret named `README_UPDATER_TOKEN`.
        - Create it under your GitHub organization settings: `https://github.com/organizations/<YOUR_ORG>/settings/secrets/actions`.
        - The updater will look for `REPO` or `GITHUB_REPOSITORY` (both usually set by GitHub Actions) to infer `<YOUR_ORG>` for guidance.
        - If `README_UPDATER_TOKEN` is missing, the tool prints a helpful error to STDERR and aborts, including a direct link to the expected org settings page.

## 🔐 Security

See [SECURITY.md][🔐security].

## 🤝 Contributing

If you need some ideas of where to help, you could work on adding more code coverage,
check [issues][🤝gh-issues] or [PRs][🤝gh-pulls], or use the gem and think about how it could be better.

We [![Keep A Changelog][📗keep-changelog-img]][📗keep-changelog] so if you make changes, remember to update it.

See [CONTRIBUTING.md][🤝contributing] for more detailed instructions.

### 🚀 Release Instructions

See [CONTRIBUTING.md][🤝contributing].

### Code Coverage

<details markdown="1">
<summary>Coverage service badges</summary>

[![Coverage Graph][🏀codecov-g]][🏀codecov]

[![Coveralls Test Coverage][🏀coveralls-img]][🏀coveralls]

[![QLTY Test Coverage][🏀qlty-covi]][🏀qlty-cov]

</details>

### 🪇 Code of Conduct

Everyone interacting with this project's codebases, issue trackers,
chat rooms and mailing lists agrees to follow the [![Contributor Covenant 2.1][🪇conduct-img]][🪇conduct].

## 🌈 Contributors

[![Contributors][🖐contributors-img]][🖐contributors]

Made with [contributors-img][🖐contrib-rocks].

Also see GitLab Contributors: [https://gitlab.com/kettle-dev/kettle-dev/-/graphs/main][🚎contributors-gl]

## 📌 Versioning

This library follows [![Semantic Versioning 2.0.0][📌semver-img]][📌semver] for its public API where practical.
For most applications, prefer the [Pessimistic Version Constraint][📌pvc] with two digits of precision.

For example:

```ruby
spec.add_dependency("kettle-dev", "~> 3.0")
```

<details markdown="1">
<summary>📌 Is "Platform Support" part of the public API? More details inside.</summary>

Dropping support for a platform can be a breaking change for affected users.
If a release changes supported platforms, it should be called out clearly in the changelog and versioned with that impact in mind.

To get a better understanding of how SemVer is intended to work over a project's lifetime,
read this article from the creator of SemVer:

- ["Major Version Numbers are Not Sacred"][📌major-versions-not-sacred]

</details>

See [CHANGELOG.md][📌changelog] for a list of releases.

## 📄 License

The gem is available under the following license: [AGPL-3.0-only](https://github.com/kettle-dev/kettle-dev/blob/main/AGPL-3.0-only.md).
See [LICENSE.md][📄license] for details.

If none of the available licenses suit your use case, please [contact us](mailto:floss@galtzo.com) to discuss a custom commercial license.

### © Copyright

See [LICENSE.md][📄license] for the official copyright notice.

<details markdown="1">
<summary>Copyright holders</summary>

- Copyright (c) 2023, 2025-2026 Peter H. Boling

</details>

## 🤑 A request for help

Maintainers have teeth and need to pay their dentists.
After getting laid off in an RIF in March, and encountering difficulty finding a new one,
I began spending most of my time building open source tools.
I'm hoping to be able to pay for my kids' health insurance this month,
so if you value the work I am doing, I need your support.
Please consider sponsoring me or the project.

To join the community or get help, use the RubyForum or Discord.

[![Ruby Users Forum][✉️ruby-forum-img]][✉️ruby-forum]
[![Live Chat on Discord][✉️discord-invite-img-ftb]][✉️discord-invite]

To say "thanks!" ☝️ Join the community or 👇️ send money.

[![Sponsor kettle-dev/kettle-dev on Open Source Collective][🖇osc-all-bottom-img]][🖇osc] 💌 [![Sponsor me on GitHub Sponsors][🖇sponsor-bottom-img]][🖇sponsor] 💌 [![Sponsor me on Liberapay][⛳liberapay-bottom-img]][⛳liberapay] 💌 [![Donate on PayPal][🖇paypal-bottom-img]][🖇paypal]

### Please give the project a star ⭐ ♥.

Many parts of this project are actively managed by a [kettle-jem](https://github.com/structuredmerge/structuredmerge-ruby/tree/main/gems/kettle-jem) smart template utilizing [StructuredMerge.org](https://structuredmerge.org) merge contracts.

Thanks for RTFM. ☺️

[⛳liberapay-img]: https://img.shields.io/liberapay/goal/pboling.svg?logo=liberapay&color=a51611&style=flat
[⛳liberapay-bottom-img]: https://img.shields.io/liberapay/goal/pboling.svg?style=for-the-badge&logo=liberapay&color=a51611
[⛳liberapay]: https://liberapay.com/pboling/donate
[🖇osc-all-img]: https://img.shields.io/opencollective/all/kettle-dev
[🖇osc-sponsors-img]: https://img.shields.io/opencollective/sponsors/kettle-dev
[🖇osc-backers-img]: https://img.shields.io/opencollective/backers/kettle-dev
[🖇osc-backers]: https://opencollective.com/kettle-dev#backer
[🖇osc-backers-i]: https://opencollective.com/kettle-dev/backers/badge.svg?style=flat
[🖇osc-sponsors]: https://opencollective.com/kettle-dev#sponsor
[🖇osc-sponsors-i]: https://opencollective.com/kettle-dev/sponsors/badge.svg?style=flat
[🖇osc-all-bottom-img]: https://img.shields.io/opencollective/all/kettle-dev?style=for-the-badge
[🖇osc-sponsors-bottom-img]: https://img.shields.io/opencollective/sponsors/kettle-dev?style=for-the-badge
[🖇osc-backers-bottom-img]: https://img.shields.io/opencollective/backers/kettle-dev?style=for-the-badge
[🖇osc]: https://opencollective.com/kettle-dev
[🖇sponsor-img]: https://img.shields.io/badge/Sponsor_Me!-pboling.svg?style=social&logo=github
[🖇sponsor-bottom-img]: https://img.shields.io/badge/Sponsor_Me!-pboling-blue?style=for-the-badge&logo=github
[🖇sponsor]: https://github.com/sponsors/pboling
[🖇kofi-img]: https://img.shields.io/badge/ko--fi-%E2%9C%93-a51611.svg?style=flat
[🖇kofi]: https://ko-fi.com/pboling
[🖇buyme-small-img]: https://img.shields.io/badge/buy_me_a_coffee-%E2%9C%93-a51611.svg?style=flat
[🖇buyme-img]: https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20latte&emoji=&slug=pboling&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff
[🖇buyme]: https://www.buymeacoffee.com/pboling
[🖇paypal-img]: https://img.shields.io/badge/donate-paypal-a51611.svg?style=flat&logo=paypal
[🖇paypal-bottom-img]: https://img.shields.io/badge/donate-paypal-a51611.svg?style=for-the-badge&logo=paypal&color=0A0A0A
[🖇paypal]: https://www.paypal.com/paypalme/peterboling
[🖇floss-funding.dev]: https://floss-funding.dev
[🖇floss-funding-gem]: https://github.com/galtzo-floss/floss_funding
[✉️discord-invite]: https://discord.gg/3qme4XHNKN
[✉️discord-invite-img-ftb]: https://img.shields.io/discord/1373797679469170758?style=for-the-badge&logo=discord
[✉️ruby-friends-img]: https://img.shields.io/badge/daily.dev-%F0%9F%92%8E_Ruby_Friends-0A0A0A?style=for-the-badge&logo=dailydotdev&logoColor=white
[✉️ruby-friends]: https://app.daily.dev/squads/rubyfriends
[✉️ruby-forum-top-img]: https://img.shields.io/discourse/topics?server=https%3A%2F%2Fwww.rubyforum.org&style=flat&logo=discourse&label=Ruby%20Users%20Forum
[✉️ruby-forum-img]: https://img.shields.io/discourse/topics?server=https%3A%2F%2Fwww.rubyforum.org&style=for-the-badge&logo=discourse&label=Ruby%20Users%20Forum
[✉️ruby-forum]: https://www.rubyforum.org/tag/kettle-dev

[✇bundle-group-pattern]: https://gist.github.com/pboling/4564780
[⛳️gem-namespace]: https://github.com/kettle-dev/kettle-dev
[⛳️namespace-img]: https://img.shields.io/badge/namespace-Kettle::Dev-3C2D2D.svg?style=square&logo=ruby&logoColor=white
[⛳️gem-name]: https://clickgems.clickhouse.com/dashboard/kettle-dev
[⛳️name-img]: https://img.shields.io/badge/name-kettle--dev-3C2D2D.svg?style=square&logo=rubygems&logoColor=red
[⛳️tag-img]: https://img.shields.io/github/tag/kettle-dev/kettle-dev.svg
[⛳️tag]: https://github.com/kettle-dev/kettle-dev/releases
[🚂maint-blog]: http://www.railsbling.com/tags/kettle-dev
[🚂maint-blog-img]: https://img.shields.io/badge/blog-railsbling-0093D0.svg?style=for-the-badge&logo=rubyonrails&logoColor=orange
[🚂maint-contact]: http://www.railsbling.com/contact
[🚂maint-contact-img]: https://img.shields.io/badge/Contact-Maintainer-0093D0.svg?style=flat&logo=rubyonrails&logoColor=red
[💖🖇linkedin]: http://www.linkedin.com/in/peterboling
[💖🖇linkedin-img]: https://img.shields.io/badge/LinkedIn-Profile-0B66C2?style=flat&logo=newjapanprowrestling
[💖✌️wellfound]: https://wellfound.com/u/peter-boling
[💖✌️wellfound-img]: https://img.shields.io/badge/peter--boling-orange?style=flat&logo=wellfound
[💖💲crunchbase]: https://www.crunchbase.com/person/peter-boling
[💖💲crunchbase-img]: https://img.shields.io/badge/peter--boling-purple?style=flat&logo=crunchbase
[💖🐘ruby-mast]: https://ruby.social/@galtzo
[💖🐘ruby-mast-img]: https://img.shields.io/mastodon/follow/109447111526622197?domain=https://ruby.social&style=flat&logo=mastodon&label=Ruby%20@galtzo
[💖🦋bluesky]: https://bsky.app/profile/galtzo.com
[💖🦋bluesky-img]: https://img.shields.io/badge/@galtzo.com-0285FF?style=flat&logo=bluesky&logoColor=white
[💖🌳linktree]: https://linktr.ee/galtzo
[💖🌳linktree-img]: https://img.shields.io/badge/galtzo-purple?style=flat&logo=linktree
[💖💁🏼‍♂️devto]: https://dev.to/galtzo
[💖💁🏼‍♂️devto-img]: https://img.shields.io/badge/dev.to-0A0A0A?style=flat&logo=devdotto&logoColor=white
[💖💁🏼‍♂️aboutme]: https://about.me/peter.boling
[💖💁🏼‍♂️aboutme-img]: https://img.shields.io/badge/about.me-0A0A0A?style=flat&logo=aboutme&logoColor=white
[💖🧊berg]: https://codeberg.org/pboling
[💖🐙hub]: https://github.org/pboling
[💖🛖hut]: https://sr.ht/~galtzo/
[💖🧪lab]: https://gitlab.com/pboling
[👨🏼‍🏫expsup-upwork]: https://www.upwork.com/freelancers/~014942e9b056abdf86?mp_source=share
[👨🏼‍🏫expsup-upwork-img]: https://img.shields.io/badge/UpWork-13544E?style=for-the-badge&logo=Upwork&logoColor=white
[👨🏼‍🏫expsup-codementor]: https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github
[👨🏼‍🏫expsup-codementor-img]: https://img.shields.io/badge/CodeMentor-Get_Help-1abc9c?style=for-the-badge&logo=CodeMentor&logoColor=white
[🏙️entsup-tidelift]: https://tidelift.com/subscription/pkg/rubygems-kettle-dev?utm_source=rubygems-kettle-dev&utm_medium=referral&utm_campaign=readme
[🏙️entsup-tidelift-img]: https://img.shields.io/badge/Tidelift_and_Sonar-Enterprise_Support-FD3456?style=for-the-badge&logo=sonar&logoColor=white
[🏙️entsup-tidelift-sonar]: https://blog.tidelift.com/tidelift-joins-sonar
[💁🏼‍♂️peterboling]: http://www.peterboling.com
[🚂railsbling]: http://www.railsbling.com
[📜src-gl-img]: https://img.shields.io/badge/GitLab-FBA326?style=for-the-badge&logo=Gitlab&logoColor=orange
[📜src-gl]: https://gitlab.com/kettle-dev/kettle-dev
[📜src-cb-img]: https://img.shields.io/badge/CodeBerg-4893CC?style=for-the-badge&logo=CodeBerg&logoColor=blue
[📜src-cb]: https://codeberg.org/kettle-dev/kettle-dev
[📜src-gh-img]: https://img.shields.io/badge/GitHub-238636?style=for-the-badge&logo=GitHub&logoColor=green
[📜src-gh]: https://github.com/kettle-dev/kettle-dev
[📜docs-cr-rd-img]: https://img.shields.io/badge/RubyDoc-Current_Release-943CD2?style=for-the-badge&logo=readthedocs&logoColor=white
[📜docs-head-rd-img]: https://img.shields.io/badge/YARD_on_Galtzo.com-HEAD-943CD2?style=for-the-badge&logo=readthedocs&logoColor=white
[📜gl-wiki]: https://gitlab.com/kettle-dev/kettle-dev/-/wikis/home
[📜gh-wiki]: https://github.com/kettle-dev/kettle-dev/wiki
[📜gl-wiki-img]: https://img.shields.io/badge/wiki-gitlab-943CD2.svg?style=for-the-badge&logo=gitlab&logoColor=white
[📜gh-wiki-img]: https://img.shields.io/badge/wiki-github-943CD2.svg?style=for-the-badge&logo=github&logoColor=white
[👽dl-rank]: https://clickgems.clickhouse.com/dashboard/kettle-dev
[👽dl-ranki]: https://img.shields.io/gem/dt/kettle-dev.svg
[👽version]: https://clickgems.clickhouse.com/dashboard/kettle-dev
[👽versioni]: https://img.shields.io/gem/v/kettle-dev.svg
[🏀qlty-mnt]: https://qlty.sh/gh/kettle-dev/projects/kettle-dev
[🏀qlty-mnti]: https://qlty.sh/gh/kettle-dev/projects/kettle-dev/maintainability.svg
[🏀qlty-cov]: https://qlty.sh/gh/kettle-dev/projects/kettle-dev/metrics/code?sort=coverageRating
[🏀qlty-covi]: https://qlty.sh/gh/kettle-dev/projects/kettle-dev/coverage.svg
[🏀codecov]: https://codecov.io/gh/kettle-dev/kettle-dev
[🏀codecovi]: https://codecov.io/gh/kettle-dev/kettle-dev/graph/badge.svg
[🏀coveralls]: https://coveralls.io/github/kettle-dev/kettle-dev?branch=main
[🏀coveralls-img]: https://coveralls.io/repos/github/kettle-dev/kettle-dev/badge.svg?branch=main
[🚎ruby-2.4-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-2.4.yml
[🚎ruby-2.5-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-2.5.yml
[🚎ruby-2.6-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-2.6.yml
[🚎ruby-2.7-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-2.7.yml
[🚎ruby-3.0-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-3.0.yml
[🚎ruby-3.1-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-3.1.yml
[🚎ruby-3.2-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-3.2.yml
[🚎ruby-3.3-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-3.3.yml
[🚎ruby-3.4-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/ruby-3.4.yml
[🚎jruby-9.2-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/jruby-9.2.yml
[🚎jruby-9.3-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/jruby-9.3.yml
[🚎jruby-9.4-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/jruby-9.4.yml
[🚎jruby-10.0-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/jruby-10.0.yml
[🚎truby-22.3-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffleruby-22.3.yml
[🚎truby-23.0-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffleruby-23.0.yml
[🚎truby-23.1-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffleruby-23.1.yml
[🚎truby-24.2-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffleruby-24.2.yml
[🚎truby-25.0-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffleruby-25.0.yml
[🚎truby-33.0-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffleruby-33.0.yml
[🚎2-cov-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/coverage.yml
[🚎2-cov-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/coverage.yml/badge.svg
[🚎3-hd-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/heads.yml
[🚎3-hd-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/heads.yml/badge.svg
[🚎5-st-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/style.yml
[🚎5-st-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/style.yml/badge.svg
[🚎9-t-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffle.yml
[🚎9-t-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/truffle.yml/badge.svg
[🚎10-j-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/jruby.yml
[🚎10-j-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/jruby.yml/badge.svg
[🚎11-c-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/current.yml
[🚎11-c-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/current.yml/badge.svg
[🚎12-crh-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/dep-heads.yml
[🚎12-crh-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/dep-heads.yml/badge.svg
[🚎13-🔒️-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/locked_deps.yml
[🚎13-🔒️-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/locked_deps.yml/badge.svg
[🚎14-🔓️-wf]: https://github.com/kettle-dev/kettle-dev/actions/workflows/unlocked_deps.yml
[🚎14-🔓️-wfi]: https://github.com/kettle-dev/kettle-dev/actions/workflows/unlocked_deps.yml/badge.svg
[💎ruby-2.4i]: https://img.shields.io/badge/Ruby-2.4-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.5i]: https://img.shields.io/badge/Ruby-2.5-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.6i]: https://img.shields.io/badge/Ruby-2.6-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.7i]: https://img.shields.io/badge/Ruby-2.7-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.0i]: https://img.shields.io/badge/Ruby-3.0-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.1i]: https://img.shields.io/badge/Ruby-3.1-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.2i]: https://img.shields.io/badge/Ruby-3.2-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.3i]: https://img.shields.io/badge/Ruby-3.3-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.4i]: https://img.shields.io/badge/Ruby-3.4-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-c-i]: https://img.shields.io/badge/Ruby-current-CC342D?style=for-the-badge&logo=ruby&logoColor=green
[💎ruby-headi]: https://img.shields.io/badge/Ruby-HEAD-CC342D?style=for-the-badge&logo=ruby&logoColor=blue
[💎truby-22.3i]: https://img.shields.io/badge/Truffle_Ruby-22.3-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-23.0i]: https://img.shields.io/badge/Truffle_Ruby-23.0-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-23.1i]: https://img.shields.io/badge/Truffle_Ruby-23.1-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-24.2i]: https://img.shields.io/badge/Truffle_Ruby-24.2-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-25.0i]: https://img.shields.io/badge/Truffle_Ruby-25.0-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-33.0i]: https://img.shields.io/badge/Truffle_Ruby-33.0-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-c-i]: https://img.shields.io/badge/Truffle_Ruby-current-34BCB1?style=for-the-badge&logo=ruby&logoColor=green
[💎truby-headi]: https://img.shields.io/badge/Truffle_Ruby-HEAD-34BCB1?style=for-the-badge&logo=ruby&logoColor=blue
[💎jruby-9.2i]: https://img.shields.io/badge/JRuby-9.2-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-9.3i]: https://img.shields.io/badge/JRuby-9.3-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-9.4i]: https://img.shields.io/badge/JRuby-9.4-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-10.0i]: https://img.shields.io/badge/JRuby-10.0-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-c-i]: https://img.shields.io/badge/JRuby-current-FBE742?style=for-the-badge&logo=ruby&logoColor=green
[💎jruby-headi]: https://img.shields.io/badge/JRuby-HEAD-FBE742?style=for-the-badge&logo=ruby&logoColor=blue
[🤝gh-issues]: https://github.com/kettle-dev/kettle-dev/issues
[🤝gh-pulls]: https://github.com/kettle-dev/kettle-dev/pulls
[🤝gl-issues]: https://gitlab.com/kettle-dev/kettle-dev/-/issues
[🤝gl-pulls]: https://gitlab.com/kettle-dev/kettle-dev/-/merge_requests
[🤝cb-issues]: https://codeberg.org/kettle-dev/kettle-dev/issues
[🤝cb-pulls]: https://codeberg.org/kettle-dev/kettle-dev/pulls
[🤝cb-donate]: https://donate.codeberg.org/
[🤝contributing]: https://github.com/kettle-dev/kettle-dev/blob/main/CONTRIBUTING.md
[🏀codecov-g]: https://codecov.io/gh/kettle-dev/kettle-dev/graph/badge.svg
[🖐contrib-rocks]: https://contrib.rocks
[🖐contributors]: https://github.com/kettle-dev/kettle-dev/graphs/contributors
[🖐contributors-img]: https://contrib.rocks/image?repo=kettle-dev/kettle-dev
[🚎contributors-gl]: https://gitlab.com/kettle-dev/kettle-dev/-/graphs/main
[🪇conduct]: https://github.com/kettle-dev/kettle-dev/blob/main/CODE_OF_CONDUCT.md
[🪇conduct-img]: https://img.shields.io/badge/Contributor_Covenant-2.1-259D6C.svg
[📌pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint
[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-259D6C.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📌changelog]: https://github.com/kettle-dev/kettle-dev/blob/main/CHANGELOG.md
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-34495e.svg?style=flat
[📌gitmoji]: https://gitmoji.dev
[📌gitmoji-img]: https://img.shields.io/badge/gitmoji_commits-%20%F0%9F%98%9C%20%F0%9F%98%8D-34495e.svg?style=flat-square
[🧮kloc]: https://www.youtube.com/watch?v=dQw4w9WgXcQ
[🧮kloc-img]: https://img.shields.io/badge/KLOC-6.635-FFDD67.svg?style=for-the-badge&logo=YouTube&logoColor=blue
[🔐security]: https://github.com/kettle-dev/kettle-dev/blob/main/SECURITY.md
[🔐security-img]: https://img.shields.io/badge/security-policy-259D6C.svg?style=flat
[📄copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year
[📄license]: LICENSE.md
[📄license-ref]: https://github.com/kettle-dev/kettle-dev/blob/main/AGPL-3.0-only.md
[📄license-img]: https://img.shields.io/badge/License-AGPL--3.0--only-259D6C.svg
[📄license-compat]: https://www.apache.org/legal/resolved.html#category-x
[📄license-compat-img]: https://img.shields.io/badge/Apache_Incompatible:_Category_X-%E2%9C%97-C0392B.svg?style=flat&logo=Apache

[📄ilo-declaration]: https://www.ilo.org/declaration/lang--en/index.htm
[📄ilo-declaration-img]: https://img.shields.io/badge/ILO_Fundamental_Principles-✓-259D6C.svg?style=flat
[🚎yard-current]: http://rubydoc.info/gems/kettle-dev
[🚎yard-head]: https://kettle-dev.galtzo.com
[💎stone_checksums]: https://github.com/galtzo-floss/stone_checksums
[💎SHA_checksums]: https://gitlab.com/kettle-dev/kettle-dev/-/tree/main/checksums
[💎rlts]: https://github.com/rubocop-lts/rubocop-lts
[💎rlts-img]: https://img.shields.io/badge/code_style_&_linting-rubocop--lts-34495e.svg?plastic&logo=ruby&logoColor=white
[💎appraisal2]: https://github.com/appraisal-rb/appraisal2
[💎appraisal2-img]: https://img.shields.io/badge/appraised_by-appraisal2-34495e.svg?plastic&logo=ruby&logoColor=white
[💎d-in-dvcs]: https://railsbling.com/posts/dvcs/put_the_d_in_dvcs/

<!-- kettle-jem:metadata:start -->
| Field | Value |
|---|---|
| Package | kettle-dev |
| Description | 🍲 Kettle::Dev is a meta tool from kettle-dev to streamline development and testing. Acts as a shim dependency, pulling in many other dependencies, to give you OOTB productivity with a RubyGem, or Ruby app project. Configures a complete set of Rake tasks, for all the libraries is brings in, so they arrive ready to go. Fund overlooked open source projects - bottom of stack, dev/test dependencies: floss-funding.dev |
| Homepage | https://github.com/kettle-dev/kettle-dev |
| Source | https://github.com/kettle-dev/kettle-dev |
| License | `AGPL-3.0-only` |
| Funding | https://github.com/sponsors/pboling, https://ko-fi.com/pboling, https://liberapay.com/pboling/donate, https://opencollective.com/kettle-dev, https://thanks.dev/u/gh/pboling, https://tidelift.com/funding/github/rubygems/kettle-dev, https://www.buymeacoffee.com/pboling |
<!-- kettle-jem:metadata:end -->
