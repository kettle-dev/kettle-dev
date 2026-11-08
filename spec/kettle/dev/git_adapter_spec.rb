# frozen_string_literal: true

RSpec.describe Kettle::Dev::GitAdapter, :real_git_adapter do
  include_context "with truffleruby 3.1..3.2 skip"

  describe "#add_repository_paths" do
    it "stages a monorepo subgem path relative to the repository root" do
      Dir.mktmpdir("kettle-dev-git-adapter-monorepo") do |repository_root|
        subgem_root = File.join(repository_root, "gems", "example")
        FileUtils.mkdir_p(subgem_root)
        File.write(File.join(subgem_root, "Gemfile.lock"), "initial\n")
        expect(system("git", "-c", "maintenance.auto=false", "init", "-q", repository_root)).to be(true)
        expect(system("git", "-C", repository_root, "config", "maintenance.auto", "false")).to be(true)
        expect(system("git", "-C", repository_root, "config", "user.email", "test@example.com")).to be(true)
        expect(system("git", "-C", repository_root, "config", "user.name", "Test User")).to be(true)
        expect(system("git", "-C", repository_root, "add", ".")).to be(true)
        expect(system("git", "-C", repository_root, "-c", "maintenance.auto=false", "commit", "-q", "-m", "initial")).to be(true)
        File.write(File.join(subgem_root, "Gemfile.lock"), "updated\n")

        adapter = described_class.new(subgem_root)
        expect(adapter.add_repository_paths(["gems/example/Gemfile.lock"])).to be(true)

        staged, staged_ok = adapter.capture(%w[diff --cached --name-only])
        expect(staged_ok).to be(true)
        expect(staged).to eq("gems/example/Gemfile.lock")
      end
    end
  end

  describe "commit hook environment" do
    it "passes explicit environment overrides through to Git hooks" do
      Dir.mktmpdir("kettle-dev-git-adapter-hooks") do |root|
        hooks = File.join(root, "hooks")
        FileUtils.mkdir_p(hooks)
        File.write(File.join(root, "README.md"), "initial\n")
        File.write(File.join(hooks, "prepare-commit-msg"), <<~SH)
          #!/bin/sh
          printf '%s|%s' "${KETTLE_DEV_DEV-unset}" "${BUNDLE_GEMFILE-unset}" > hook-environment.txt
        SH
        FileUtils.chmod(0o755, File.join(hooks, "prepare-commit-msg"))
        expect(system("git", "-c", "maintenance.auto=false", "init", "-q", root)).to be(true)
        expect(system("git", "-C", root, "config", "maintenance.auto", "false")).to be(true)
        expect(system("git", "-C", root, "config", "user.email", "test@example.com")).to be(true)
        expect(system("git", "-C", root, "config", "user.name", "Test User")).to be(true)
        expect(system("git", "-C", root, "config", "core.hooksPath", hooks)).to be(true)
        expect(system("git", "-C", root, "add", "README.md")).to be(true)

        adapter = described_class.new(root)
        environment = {"KETTLE_DEV_DEV" => "false", "BUNDLE_GEMFILE" => nil}

        expect(adapter.commit_staged("chore(deps): 🔒️ update Bundler lockfiles", env: environment)).to be(true)
        expect(File.read(File.join(root, "hook-environment.txt"))).to eq("false|unset")
      end
    end
  end

  describe "git operations with git gem present" do
    let(:git_repo) { double("Git::Base") }

    it "pushes to named remote and returns true" do
      allow(git_repo).to receive(:push).with("origin", "feat", force: false)
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.push("origin", "feat")).to be true
      expect(git_repo).to have_received(:push).with("origin", "feat", force: false)
    end

    it "pushes to default remote when remote is nil" do
      allow(git_repo).to receive(:push).with(nil, "main", force: true)
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.push(nil, "main", force: true)).to be true
      expect(git_repo).to have_received(:push).with(nil, "main", force: true)
    end

    it "returns false on exceptions in push" do
      allow(git_repo).to receive(:push).and_raise(StandardError)
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.push("origin", "feat")).to be false
    end

    it "returns current_branch and handles error" do
      allow(git_repo).to receive(:current_branch).and_return("main")
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.current_branch).to eq("main")
      allow(git_repo).to receive(:current_branch).and_raise(StandardError)
      expect(adapter.current_branch).to be_nil
    end

    it "lists remotes and handles error" do
      remote_a = double("Git::Remote", name: "origin")
      remote_b = double("Git::Remote", name: "github")
      allow(git_repo).to receive(:remotes).and_return([remote_a, remote_b])
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.remotes).to eq(["origin", "github"])
      allow(git_repo).to receive(:remotes).and_raise(StandardError)
      expect(adapter.remotes).to be_empty
    end

    it "returns remotes_with_urls and handles error" do
      remote_a = double("Git::Remote", name: "origin", url: "git@github.com:me/repo.git")
      remote_b = double("Git::Remote", name: "github", url: "https://github.com/me/repo.git")
      allow(git_repo).to receive(:remotes).and_return([remote_a, remote_b])
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.remotes_with_urls).to eq({
        "origin" => "git@github.com:me/repo.git",
        "github" => "https://github.com/me/repo.git"
      })
      allow(git_repo).to receive(:remotes).and_raise(StandardError)
      expect(adapter.remotes_with_urls).to eq({})
    end

    it "returns remote_url and handles error" do
      remote_a = double("Git::Remote", name: "origin", url: "git@github.com:me/repo.git")
      allow(git_repo).to receive(:remotes).and_return([remote_a])
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.remote_url("origin")).to include("github.com")
      allow(git_repo).to receive(:remotes).and_raise(StandardError)
      expect(adapter.remote_url("origin")).to be_nil
    end

    it "checks out a branch and returns false on error" do
      allow(git_repo).to receive(:checkout).with("feat")
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.checkout("feat")).to be true
      expect(git_repo).to have_received(:checkout).with("feat")
      allow(git_repo).to receive(:checkout).and_raise(StandardError)
      expect(adapter.checkout("feat")).to be false
    end

    it "pulls and returns false on error" do
      allow(git_repo).to receive(:pull).with("origin", "main")
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.pull("origin", "main")).to be true
      expect(git_repo).to have_received(:pull).with("origin", "main")
      allow(git_repo).to receive(:pull).and_raise(StandardError)
      expect(adapter.pull("origin", "main")).to be false
    end

    it "fetches with and without ref and returns false on error" do
      allow(git_repo).to receive(:fetch)
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      expect(adapter.fetch("origin", "main")).to be true
      expect(git_repo).to have_received(:fetch).with("origin", "main")
      expect(adapter.fetch("origin")).to be true
      expect(git_repo).to have_received(:fetch).with("origin")
      allow(git_repo).to receive(:fetch).and_raise(StandardError)
      expect(adapter.fetch("origin", "oops")).to be false
    end

    # New tests for push_tags behavior under gem backend (shells out)
    it "pushes tags to a named remote via system even with gem backend" do
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      allow(adapter).to receive(:system).with("git", "push", "origin", "--tags").and_return(true)
      expect(adapter.push_tags("origin")).to be true
      expect(adapter).to have_received(:system).with("git", "push", "origin", "--tags")
    end

    it "pushes tags without specifying remote when remote is nil or empty" do
      adapter = described_class.new
      adapter.instance_variable_set(:@backend, :gem)
      adapter.instance_variable_set(:@git, git_repo)
      allow(adapter).to receive(:system).with("git", "push", "--tags").and_return(true)
      expect(adapter.push_tags(nil)).to be true
      expect(adapter).to have_received(:system).with("git", "push", "--tags")
      # also cover empty string
      adapter2 = described_class.new
      adapter2.instance_variable_set(:@backend, :gem)
      adapter2.instance_variable_set(:@git, git_repo)
      allow(adapter2).to receive(:system).with("git", "push", "--tags").and_return(true)
      expect(adapter2.push_tags("")).to be true
      expect(adapter2).to have_received(:system).with("git", "push", "--tags")
    end
  end

  describe "CLI fallback when git gem is missing" do
    let(:status_ok) { instance_double(Process::Status, success?: true) }
    let(:git_load_error) { LoadError.new("cannot load such file -- git") }

    before do
      # Make `require "git"` raise, to trigger CLI backend
      allow(Kernel).to receive(:require).with("git").and_raise(git_load_error)
    end

    it "suppresses the backtrace when the optional git gem is unavailable" do
      allow(Kettle::Dev).to receive(:debug_error)

      adapter = described_class.new

      expect(adapter.instance_variable_get(:@backend)).to eq(:cli)
      expect(Kettle::Dev).to have_received(:debug_error).with(git_load_error, :initialize, backtrace: false)
    end

    it "pushes using system git with remote and without" do
      adapter = described_class.new
      allow(adapter).to receive(:system).and_return(true)
      expect(adapter.push("origin", "feat")).to be true
      expect(adapter).to have_received(:system).with("git", "push", "origin", "feat")
      expect(adapter.push(nil, "feat")).to be true
      expect(adapter).to have_received(:system).with("git", "push")
    end

    it "pushes with --force when requested" do
      adapter = described_class.new
      allow(adapter).to receive(:system).and_return(true)
      expect(adapter.push("origin", "main", force: true)).to be true
      expect(adapter).to have_received(:system).with("git", "push", "--force", "origin", "main")
      expect(adapter.push(nil, "main", force: true)).to be true
      expect(adapter).to have_received(:system).with("git", "push", "--force")
    end

    it "returns current branch via rev-parse" do
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "--abbrev-ref", "HEAD").and_return(["main\n", status_ok])
      adapter = described_class.new
      expect(adapter.current_branch).to eq("main")
      expect(Open3).to have_received(:capture2).with("git", "rev-parse", "--abbrev-ref", "HEAD")
    end

    it "lists remotes from `git remote`" do
      allow(Open3).to receive(:capture2).with("git", "remote").and_return(["origin\ngithub\n", status_ok])
      adapter = described_class.new
      expect(adapter.remotes).to eq(["origin", "github"])
      expect(Open3).to have_received(:capture2).with("git", "remote")
    end

    it "parses remotes_with_urls from `git remote -v`" do
      lines = <<~OUT
        origin https://github.com/me/repo.git (fetch)
        origin https://github.com/me/repo.git (push)
        gl     https://gitlab.com/me/repo (fetch)
        gl     https://gitlab.com/me/repo (push)
      OUT
      allow(Open3).to receive(:capture2).with("git", "remote", "-v").and_return([lines, status_ok])
      adapter = described_class.new
      urls = adapter.remotes_with_urls
      # Be flexible: accept SSH or HTTPS; only assert the domains are present
      expect(urls.fetch("origin")).to include("github.com")
      expect(urls.fetch("gl")).to include("gitlab.com")
      expect(Open3).to have_received(:capture2).with("git", "remote", "-v")
    end

    it "gets remote_url via git config" do
      allow(Open3).to receive(:capture2).with("git", "config", "--get", "remote.origin.url").and_return(["git@github.com:me/repo.git\n", status_ok])
      adapter = described_class.new
      expect(adapter.remote_url("origin")).to include("github.com")
      expect(Open3).to have_received(:capture2).with("git", "config", "--get", "remote.origin.url")
    end

    it "checkout/pull/fetch use system git" do
      adapter = described_class.new
      allow(adapter).to receive(:system).and_return(true)
      expect(adapter.checkout("main")).to be true
      expect(adapter).to have_received(:system).with("git", "checkout", "main")
      expect(adapter.pull("origin", "main")).to be true
      expect(adapter).to have_received(:system).with("git", "pull", "origin", "main")
      expect(adapter.fetch("origin", "main")).to be true
      expect(adapter).to have_received(:system).with("git", "fetch", "origin", "main")
      expect(adapter.fetch("origin")).to be true
      expect(adapter).to have_received(:system).with("git", "fetch", "origin")
    end

    # New tests for push_tags behavior under CLI backend
    it "pushes tags to named remote via system with CLI backend" do
      adapter = described_class.new
      allow(adapter).to receive(:system).with("git", "push", "origin", "--tags").and_return(true)
      expect(adapter.push_tags("origin")).to be true
      expect(adapter).to have_received(:system).with("git", "push", "origin", "--tags")
    end

    it "pushes tags without remote via system with CLI backend" do
      adapter = described_class.new
      allow(adapter).to receive(:system).with("git", "push", "--tags").and_return(true)
      expect(adapter.push_tags(nil)).to be true
      expect(adapter).to have_received(:system).with("git", "push", "--tags")
    end

    it "commits only changes already staged by the caller" do
      adapter = described_class.new
      allow(adapter).to receive(:system).with("git", "commit", "-m", "chore(deps): 🔒️ update Bundler lockfiles").and_return(true)

      expect(adapter.commit_staged("chore(deps): 🔒️ update Bundler lockfiles")).to be true
      expect(adapter).to have_received(:system).with("git", "commit", "-m", "chore(deps): 🔒️ update Bundler lockfiles")
    end

    it "passes an explicit environment to commit hooks" do
      adapter = described_class.new
      environment = {"KETTLE_DEV_DEV" => "false"}
      allow(adapter).to receive(:system).with(environment, "git", "commit", "-m", "chore(deps): 🔒️ update Bundler lockfiles").and_return(true)

      expect(adapter.commit_staged("chore(deps): 🔒️ update Bundler lockfiles", env: environment)).to be true
      expect(adapter).to have_received(:system).with(environment, "git", "commit", "-m", "chore(deps): 🔒️ update Bundler lockfiles")
    end

    it "uses env -u for nil-valued hook environment overrides on Unix" do
      skip "Windows does not provide POSIX env -u" if Gem.win_platform?

      adapter = described_class.new
      environment = {"KETTLE_DEV_DEV" => "false", "BUNDLE_GEMFILE" => nil}
      allow(adapter).to receive(:system)
        .with({}, "env", "-u", "BUNDLE_GEMFILE", "KETTLE_DEV_DEV=false", "git", "commit", "-m", "chore(deps): 🔒️ update Bundler lockfiles")
        .and_return(true)

      expect(adapter.commit_staged("chore(deps): 🔒️ update Bundler lockfiles", env: environment)).to be(true)
      expect(adapter).to have_received(:system)
        .with({}, "env", "-u", "BUNDLE_GEMFILE", "KETTLE_DEV_DEV=false", "git", "commit", "-m", "chore(deps): 🔒️ update Bundler lockfiles")
    end

    it "stages repository-root-relative paths from a monorepo subdirectory" do
      adapter = described_class.new("/workspace/monorepo/gems/example")
      allow(adapter).to receive(:git_system)
        .with("add", "--", ":(top)gems/example/Gemfile.lock")
        .and_return(true)

      expect(adapter.add_repository_paths(["gems/example/Gemfile.lock"])).to be(true)
    end
  end

  describe "ENV override to disable git gem" do
    # rubocop:disable RSpec/LeakyConstantDeclaration
    # Ensure verifying doubles work even when the git gem is not installed.
    unless defined?(Git)
      module ::Git; end
    end
    unless defined?(Git::Base)
      class ::Git::Base; end
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    let(:git_repo) { instance_double("Git::Base") } # rubocop:disable RSpec/VerifiedDoubleReference
    # Detect whether the 'git' gem is actually available in this environment.
    # We attempt to require it; if it is not installed, we'll skip tests that
    # need the constant ::Git to exist.
    let(:git_gem_available) do
      begin
        require "git"
        true
      rescue LoadError
        false
      end
    end

    it "uses gem backend when available and no override" do
      skip "git gem not available in this environment" unless git_gem_available
      # Simulate git gem available
      allow(Kernel).to receive(:require).with("git").and_return(true)
      allow(Git).to receive(:open).and_return(git_repo)
      allow(git_repo).to receive(:push).and_return(true)
      adapter = described_class.new
      expect(adapter.push("origin", "feat")).to be true
      expect(git_repo).to have_received(:push).with("origin", "feat", force: false)
    end

    it "forces CLI backend when KETTLE_DEV_DISABLE_GIT_GEM is truthy even if gem is available" do
      stub_env("KETTLE_DEV_DISABLE_GIT_GEM" => "true")
      # Even if require succeeds, we must not use ::Git.open in this mode.
      allow(Kernel).to receive(:require).with("git").and_return(true)
      allow(Git).to receive(:open) if defined?(Git)
      adapter = described_class.new
      allow(adapter).to receive(:system).and_return(true)
      expect(adapter.push("origin", "feat")).to be true
      expect(adapter).to have_received(:system).with("git", "push", "origin", "feat")
    end
  end

  # Consolidated from git_adapter_clean_spec.rb: clean? behavior
  describe "#clean?" do
    context "when using git gem backend" do
      let(:git_repo) { double("Git::Base") }
      let(:status_obj) { double("Git::Status", changed: {}, added: {}, deleted: {}, untracked: {}) }

      it "returns true when status has no changes" do
        adapter = described_class.new
        adapter.instance_variable_set(:@backend, :gem)
        adapter.instance_variable_set(:@git, git_repo)
        allow(git_repo).to receive(:status).and_return(status_obj)
        expect(adapter.clean?).to be true
        expect(git_repo).to have_received(:status)
      end

      it "returns false when there are any changes" do
        dirty_status = double("Git::Status", changed: {"a" => "M"}, added: {}, deleted: {}, untracked: {})
        adapter = described_class.new
        adapter.instance_variable_set(:@backend, :gem)
        adapter.instance_variable_set(:@git, git_repo)
        allow(git_repo).to receive(:status).and_return(dirty_status)
        expect(adapter.clean?).to be false
        expect(git_repo).to have_received(:status)
      end

      it "returns false when status raises an error" do
        adapter = described_class.new
        adapter.instance_variable_set(:@backend, :gem)
        adapter.instance_variable_set(:@git, git_repo)
        allow(git_repo).to receive(:status).and_raise(StandardError)
        expect(adapter.clean?).to be false
      end
    end

    context "when using CLI backend" do
      let(:ok) { instance_double(Process::Status, success?: true) }
      let(:fail_status) { instance_double(Process::Status, success?: false) }

      before do
        allow(Kernel).to receive(:require).with("git").and_raise(LoadError)
      end

      it "returns true when porcelain output is empty" do
        allow(Open3).to receive(:capture2).with("git", "status", "--porcelain").and_return(["\n", ok])
        adapter = described_class.new
        expect(adapter.clean?).to be true
        expect(Open3).to have_received(:capture2).with("git", "status", "--porcelain")
      end

      it "returns false when porcelain output has content" do
        allow(Open3).to receive(:capture2).with("git", "status", "--porcelain").and_return([" M lib/file.rb\n?? new.rb\n", ok])
        adapter = described_class.new
        expect(adapter.clean?).to be false
        expect(Open3).to have_received(:capture2).with("git", "status", "--porcelain")
      end

      it "returns false when git status fails" do
        allow(Open3).to receive(:capture2).with("git", "status", "--porcelain").and_return(["", fail_status])
        adapter = described_class.new
        expect(adapter.clean?).to be false
        expect(Open3).to have_received(:capture2).with("git", "status", "--porcelain")
      end

      it "returns false on unexpected errors" do
        allow(Open3).to receive(:capture2).and_raise(StandardError)
        adapter = described_class.new
        expect(adapter.clean?).to be false
      end
    end
  end

  describe "#diff_head_quiet?" do
    let(:ok) { instance_double(Process::Status, success?: true) }
    let(:fail_status) { instance_double(Process::Status, success?: false) }

    before { allow(Kernel).to receive(:require).with("git").and_raise(LoadError) }

    it "checks whether a path differs from HEAD" do
      allow(Open3).to receive(:capture2).with("git", "diff", "--quiet", "HEAD", "--", "Gemfile.lock")
        .and_return(["", ok])
      adapter = described_class.new

      expect(adapter.diff_head_quiet?("Gemfile.lock")).to be(true)
    end

    it "returns false when a path differs from HEAD" do
      allow(Open3).to receive(:capture2).with("git", "diff", "--quiet", "HEAD", "--", "Gemfile.lock")
        .and_return(["", fail_status])
      adapter = described_class.new

      expect(adapter.diff_head_quiet?("Gemfile.lock")).to be(false)
    end
  end

  describe "#ls_files" do
    let(:ok) { instance_double(Process::Status, success?: true) }
    let(:fail_status) { instance_double(Process::Status, success?: false) }

    before { allow(Kernel).to receive(:require).with("git").and_raise(LoadError) }

    it "returns a list of relative file paths on success" do
      allow(Open3).to receive(:capture2).with("git", "ls-files")
        .and_return(["lib/foo.rb\nlib/bar.rb\n", ok])
      adapter = described_class.new
      expect(adapter.ls_files).to eq(["lib/foo.rb", "lib/bar.rb"])
    end

    it "returns an empty array when no files are tracked" do
      allow(Open3).to receive(:capture2).with("git", "ls-files").and_return(["", ok])
      adapter = described_class.new
      expect(adapter.ls_files).to be_empty
    end

    it "returns an empty array when the git command fails" do
      allow(Open3).to receive(:capture2).with("git", "ls-files").and_return(["", fail_status])
      adapter = described_class.new
      expect(adapter.ls_files).to be_empty
    end

    it "returns an empty array when Open3 raises" do
      allow(Open3).to receive(:capture2).with("git", "ls-files").and_raise(StandardError, "boom")
      adapter = described_class.new
      expect(adapter.ls_files).to be_empty
    end
  end

  describe "#blame_porcelain" do
    let(:ok) { instance_double(Process::Status, success?: true) }
    let(:fail_status) { instance_double(Process::Status, success?: false) }
    let(:sample_output) { "abc123 1 1 1\nauthor Alice\nauthor-mail <alice@example.com>\nauthor-time 1700000000\nfilename lib/foo.rb\n\thello\n" }

    before { allow(Kernel).to receive(:require).with("git").and_raise(LoadError) }

    it "returns raw porcelain output for a tracked file" do
      allow(Open3).to receive(:capture2).with("git", "blame", "--porcelain", "lib/foo.rb")
        .and_return([sample_output, ok])
      adapter = described_class.new
      expect(adapter.blame_porcelain("lib/foo.rb")).to eq(sample_output)
    end

    it "returns an empty string when the file is untracked (non-zero exit)" do
      allow(Open3).to receive(:capture2).with("git", "blame", "--porcelain", "unknown.rb")
        .and_return(["", fail_status])
      adapter = described_class.new
      expect(adapter.blame_porcelain("unknown.rb")).to eq("")
    end

    it "returns an empty string when the git command fails" do
      allow(Open3).to receive(:capture2).with("git", "blame", "--porcelain", "lib/foo.rb")
        .and_return(["", fail_status])
      adapter = described_class.new
      expect(adapter.blame_porcelain("lib/foo.rb")).to eq("")
    end

    it "returns an empty string when Open3 raises" do
      allow(Open3).to receive(:capture2).with("git", "blame", "--porcelain", "lib/foo.rb")
        .and_raise(StandardError, "no git")
      adapter = described_class.new
      expect(adapter.blame_porcelain("lib/foo.rb")).to eq("")
    end
  end
end
