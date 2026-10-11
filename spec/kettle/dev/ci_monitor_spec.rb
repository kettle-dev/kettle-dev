# frozen_string_literal: true

RSpec.describe Kettle::Dev::CIMonitor do
  let(:helpers) { Kettle::Dev::CIHelpers }

  describe Kettle::Dev::CIHelpers do
    it "uses the configured monorepo root for CI monitoring" do
      allow(helpers).to receive(:project_root).and_return("/member")
      stub_env("K_RELEASE_CI_ROOT" => "/monorepo")

      expect(helpers.ci_project_root).to eq("/monorepo")
    end
  end

  describe "::monitor_gitlab! minutes exhausted handling" do
    it "treats insufficient quota/minutes as unknown and continues", :check_output do
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat")
      # Pretend .gitlab-ci.yml exists and there is a gitlab remote
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive(:gitlab_remote_candidates).and_return(["gitlab"])

      allow(helpers).to receive(:repo_info_gitlab).and_return(["me", "repo"])

      # Return a pipeline hash that indicates failure with insufficient quota
      pipe = {"status" => "failed", "web_url" => "https://gitlab.com/me/repo/-/pipelines/1", "id" => 1, "failure_reason" => "insufficient_quota"}
      allow(helpers).to receive_messages(gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: true)

      expect { described_class.monitor_gitlab!(restart_hint: "hint") }.not_to raise_error
    end

    it "treats blocked status as unknown and continues", :check_output do
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive(:gitlab_remote_candidates).and_return(["gitlab"])

      allow(helpers).to receive(:repo_info_gitlab).and_return(["me", "repo"])

      pipe = {"status" => "blocked", "web_url" => "https://gitlab.com/me/repo/-/pipelines/2", "id" => 2}
      allow(helpers).to receive_messages(gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: false)

      expect { described_class.monitor_gitlab!(restart_hint: "hint") }.not_to raise_error
    end

    it "still aborts on a normal failure", :check_output do
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive(:gitlab_remote_candidates).and_return(["gitlab"])

      allow(helpers).to receive(:repo_info_gitlab).and_return(["me", "repo"])

      pipe = {"status" => "failed", "web_url" => "https://gitlab.com/me/repo/-/pipelines/3", "id" => 3, "failure_reason" => "script_failure"}
      allow(helpers).to receive_messages(gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: true)

      expect { described_class.monitor_gitlab!(restart_hint: "hint") }.to raise_error(MockSystemExit, /Pipeline failed:/)
    end

    it "continues after a normal failure when CI failures are allowed", :check_output do
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive(:gitlab_remote_candidates).and_return(["gitlab"])

      allow(helpers).to receive(:repo_info_gitlab).and_return(["me", "repo"])

      pipe = {"status" => "failed", "web_url" => "https://gitlab.com/me/repo/-/pipelines/4", "id" => 4, "failure_reason" => "script_failure"}
      allow(helpers).to receive_messages(gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: true)
      stub_env("K_RELEASE_CI_CONTINUE" => "true")

      expect(described_class.monitor_gitlab!(restart_hint: "hint")).to be false
    end

    it "returns false when gitlab not configured" do
      allow(helpers).to receive(:project_root).and_return(Dir.pwd)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(false)
      allow(described_class).to receive(:gitlab_remote_candidates).and_return([])
      expect(described_class.monitor_gitlab!(restart_hint: "hint")).to be false
    end
  end

  describe "github helper branches" do
    it "defaults GitHub workflow start timeout to five minutes" do
      stub_env("K_RELEASE_CI_START_TIMEOUT" => nil)

      expect(described_class.github_start_timeout).to eq(300)
    end

    it "waits initial seconds before polling GitHub (configurable via K_RELEASE_CI_INITIAL_SLEEP)", :check_output do
      # Arrange a minimal GitHub setup
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        workflows_list: ["ci.yml"],
        current_branch: "main",
        current_head_sha: "abc123",
        latest_run: {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/1", "id" => 1}
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )

      # Expect initial sleep to be called with our configured value, then allow other sleeps (loop) to be stubbed
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "5")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint") }.not_to raise_error
      expect(described_class).to have_received(:sleep).with(5)
    end

    it "waits for the local HEAD workflow run instead of failing on an older branch run", :check_output do
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        workflows_list: ["ci.yml"],
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", require_head: true, head_sha: "abc123").and_return(
        nil,
        {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/2", "id" => 2, "head_sha" => "abc123"}
      )
      allow(helpers).to receive(:success?) { |run| run && run["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |run| run && run["conclusion"] == "failure" }
      allow(described_class).to receive(:monotonic_time).and_return(0, 1)
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0", "K_RELEASE_CI_START_TIMEOUT" => "10", "K_RELEASE_CI_POLL_INTERVAL" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint") }.not_to raise_error
    end

    it "polls every workflow again before the global start timeout expires", :check_output do
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        workflows_list: %w[first.yml second.yml third.yml],
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      calls = 0
      allow(helpers).to receive(:latest_run) do
        calls += 1
        if calls <= 3
          nil
        else
          {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/#{calls}", "id" => calls, "head_sha" => "abc123"}
        end
      end
      allow(helpers).to receive(:success?) { |run| run && run["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |run| run && run["conclusion"] == "failure" }
      allow(described_class).to receive(:monotonic_time).and_return(0, 0, 1)
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0", "K_RELEASE_CI_START_TIMEOUT" => "1", "K_RELEASE_CI_POLL_INTERVAL" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint") }.not_to raise_error
      expect(calls).to eq(6)
    end

    it "monitors an explicit workflow subset when provided", :check_output do
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        current_branch: "main",
        current_head_sha: "abc123"
      )
      expect(helpers).not_to receive(:workflows_list)
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "current.yml", branch: "main", require_head: true, head_sha: "abc123").and_return(
        {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/2", "id" => 2, "head_sha" => "abc123"}
      )
      allow(helpers).to receive(:success?) { |run| run && run["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |run| run && run["conclusion"] == "failure" }
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint", workflows: ["current.yml"]) }.not_to raise_error
    end

    it "emits per-workflow GitHub CI monitor events", :check_output do
      io = StringIO.new
      event_recorder = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      run = {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/2", "id" => 2, "head_sha" => "abc123"}
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "current.yml", branch: "main", require_head: true, head_sha: "abc123").and_return(run)
      allow(helpers).to receive(:success?) { |candidate| candidate && candidate["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |candidate| candidate && candidate["conclusion"] == "failure" }
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0")
      allow(described_class).to receive(:sleep)

      expect do
        described_class.monitor_all!(restart_hint: "hint", workflows: ["current.yml"], event_recorder: event_recorder)
      end.not_to raise_error

      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events).to include(
        include(
          "type" => "ci_monitor",
          "action" => "github_discover",
          "status" => "started",
          "provider" => "github",
          "workflows" => ["current.yml"],
          "total" => 1,
          "mark" => ">"
        ),
        include(
          "type" => "ci_monitor",
          "action" => "github_wait",
          "status" => "started",
          "provider" => "github",
          "completed" => 0,
          "total" => 1,
          "mark" => ">"
        ),
        include(
          "type" => "ci_monitor",
          "action" => "github_workflow",
          "status" => "started",
          "provider" => "github",
          "workflow" => "current.yml",
          "mark" => ">"
        ),
        include(
          "type" => "ci_monitor",
          "action" => "github_started",
          "status" => "ok",
          "provider" => "github",
          "completed" => 0,
          "total" => 1,
          "started" => 1,
          "mark" => "."
        ),
        include(
          "type" => "ci_monitor",
          "action" => "github_workflow",
          "status" => "ok",
          "provider" => "github",
          "workflow" => "current.yml",
          "completed" => 1,
          "total" => 1,
          "mark" => "."
        ),
        include(
          "type" => "ci_monitor",
          "action" => "github_tick",
          "status" => "started",
          "provider" => "github",
          "workflow" => "current.yml",
          "completed_workflow" => "current.yml",
          "completed" => 1,
          "total" => 1,
          "mark" => ">"
        ),
        include(
          "type" => "ci_monitor",
          "action" => "github_complete",
          "status" => "ok",
          "provider" => "github",
          "completed" => 1,
          "total" => 1,
          "mark" => "."
        )
      )
    end

    it "emits per-workflow GitHub CI monitor failure events", :check_output do
      io = StringIO.new
      event_recorder = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      run = {"status" => "completed", "conclusion" => "failure", "html_url" => "https://github.com/me/repo/actions/runs/3", "id" => 3, "head_sha" => "abc123"}
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "current.yml", branch: "main", require_head: true, head_sha: "abc123").and_return(run)
      allow(helpers).to receive(:success?) { |candidate| candidate && candidate["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |candidate| candidate && candidate["conclusion"] == "failure" }
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint", workflows: ["current.yml"], event_recorder: event_recorder) }.to raise_error(MockSystemExit, /Workflow failed/)

      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events).to include(
        include("type" => "ci_monitor", "action" => "github_workflow", "status" => "failed", "provider" => "github", "workflow" => "current.yml", "url" => "https://github.com/me/repo/actions/runs/3", "reason" => "Workflow failed", "mark" => "!")
      )
    end

    it "aborts naming the failed job while the run is still in progress", :check_output do
      io = StringIO.new
      event_recorder = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      run = {"status" => "in_progress", "conclusion" => nil, "html_url" => "https://github.com/me/repo/actions/runs/9", "id" => 9, "head_sha" => "abc123"}
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "current.yml", branch: "main", require_head: true, head_sha: "abc123").and_return(run)
      allow(helpers).to receive(:success?) { |candidate| candidate && candidate["status"] == "completed" && candidate["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |candidate| candidate && candidate["status"] == "completed" && candidate["conclusion"] && candidate["conclusion"] != "success" }
      allow(helpers).to receive(:run_jobs).with(owner: "me", repo: "repo", run_id: 9).and_return(
        [
          {"name" => "Deps @ HEAD (gems/ast-merge-git)", "status" => "completed", "conclusion" => "failure", "html_url" => "https://github.com/me/repo/actions/runs/9/job/1"},
          {"name" => "Other job", "status" => "in_progress", "conclusion" => nil, "html_url" => "https://github.com/me/repo/actions/runs/9/job/2"}
        ]
      )
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint", workflows: ["current.yml"], event_recorder: event_recorder) }.to raise_error(MockSystemExit, /Workflow failed \(job: Deps @ HEAD \(gems\/ast-merge-git\)\)/)

      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events).to include(
        include("type" => "ci_monitor", "action" => "github_workflow", "status" => "failed", "provider" => "github", "workflow" => "current.yml", "failed_job" => "Deps @ HEAD (gems/ast-merge-git)", "mark" => "!")
      )
    end

    it "keeps waiting while an in-progress run has no failed jobs" do
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      in_progress = {"status" => "in_progress", "conclusion" => nil, "html_url" => "https://github.com/me/repo/actions/runs/10", "id" => 10, "head_sha" => "abc123"}
      done = {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/10", "id" => 10, "head_sha" => "abc123"}
      calls = 0
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "current.yml", branch: "main", require_head: true, head_sha: "abc123") do
        calls += 1
        (calls <= 1) ? in_progress : done
      end
      allow(helpers).to receive(:success?) { |candidate| candidate && candidate["status"] == "completed" && candidate["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |candidate| candidate && candidate["status"] == "completed" && candidate["conclusion"] && candidate["conclusion"] != "success" }
      allow(helpers).to receive(:run_jobs).with(owner: "me", repo: "repo", run_id: 10).and_return(
        [{"name" => "Pending job", "status" => "in_progress", "conclusion" => nil, "html_url" => "https://github.com/me/repo/actions/runs/10/job/1"}]
      )
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint", workflows: ["current.yml"]) }.not_to raise_error
      expect(calls).to eq(2)
    end

    it "continues monitoring remaining workflows when CI failures are allowed", :check_output do
      io = StringIO.new
      event_recorder = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git",
        gitlab_remote_candidates: []
      )
      allow(helpers).to receive(:latest_run) do |workflow_file:, **|
        if workflow_file == "current.yml"
          {"status" => "completed", "conclusion" => "failure", "html_url" => "https://github.com/me/repo/actions/runs/4", "id" => 4, "head_sha" => "abc123"}
        else
          {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/5", "id" => 5, "head_sha" => "abc123"}
        end
      end
      allow(helpers).to receive(:success?) { |candidate| candidate && candidate["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |candidate| candidate && candidate["conclusion"] == "failure" }
      stub_env("K_RELEASE_CI_CONTINUE" => "true", "K_RELEASE_CI_INITIAL_SLEEP" => "0", "K_RELEASE_CI_POLL_INTERVAL" => "0")
      allow(described_class).to receive(:sleep)

      result = described_class.monitor_all!(
        restart_hint: "hint",
        workflows: %w[current.yml style.yml],
        event_recorder: event_recorder
      )

      expect(result).to be(false)
      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events).to include(
        include("type" => "ci_monitor", "action" => "github_workflow", "status" => "failed", "workflow" => "current.yml"),
        include("type" => "ci_monitor", "action" => "github_workflow", "status" => "ok", "workflow" => "style.yml"),
        include("type" => "ci_monitor", "action" => "github_complete", "status" => "failed", "completed" => 2, "failed" => ["current.yml"])
      )
    end

    it "rate-limits release secret keepalive callbacks during CI polling" do
      calls = 0
      stub_env("KETTLE_RELEASE_SECRET_KEEPALIVE_INTERVAL" => "10")
      timer = described_class.keepalive_timer(-> { calls += 1 })
      allow(described_class).to receive(:monotonic_time).and_return(0, 5, 11)

      3.times { timer.call }

      expect(calls).to eq(2)
    end

    it "times out when GitHub never starts a run for local HEAD", :check_output do
      allow(helpers).to receive_messages(
        project_root: Dir.pwd,
        workflows_list: ["ci.yml"],
        current_branch: "main",
        current_head_sha: "abc123"
      )
      allow(described_class).to receive_messages(
        preferred_github_remote: "origin",
        remote_url: "https://github.com/me/repo.git"
      )
      allow(helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", require_head: true, head_sha: "abc123").and_return(nil)
      allow(described_class).to receive(:monotonic_time).and_return(0, 1)
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0", "K_RELEASE_CI_START_TIMEOUT" => "0", "K_RELEASE_CI_POLL_INTERVAL" => "0")
      allow(described_class).to receive(:sleep)

      expect { described_class.monitor_all!(restart_hint: "hint") }.to raise_error(MockSystemExit, /Timed out.*HEAD abc123/)
    end

    it "preferred_github_remote returns nil when no candidates" do
      allow(described_class).to receive(:remotes_with_urls).and_return({})
      expect(described_class.preferred_github_remote).to be_nil
    end

    it "preferred_github_remote prefers explicit then origin then first" do
      allow(described_class).to receive(:remotes_with_urls).and_return({
        "origin" => "https://github.com/me/repo.git",
        "github" => "https://github.com/me/repo.git"
      })
      expect(described_class.preferred_github_remote).to eq("github")
      allow(described_class).to receive(:remotes_with_urls).and_return({
        "origin" => "https://github.com/me/repo.git",
        "upstream" => "https://github.com/me/repo.git"
      })
      expect(described_class.preferred_github_remote).to eq("origin")
      allow(described_class).to receive(:remotes_with_urls).and_return({
        "foo" => "https://github.com/me/repo.git",
        "bar" => "https://github.com/me/other.git"
      })
      expect(described_class.preferred_github_remote).to eq("foo")
    end

    it "parse_github_owner_repo handles nil and unknown patterns" do
      expect(described_class.parse_github_owner_repo(nil)).to eq([nil, nil])
      expect(described_class.parse_github_owner_repo("ssh://gitlab.com/u/r")).to eq([nil, nil])
    end

    it "parses SSH and HTTPS URLs" do
      expect(described_class.parse_github_owner_repo("git@github.com:me/repo.git")).to eq(["me", "repo"])
      expect(described_class.parse_github_owner_repo("git+ssh://git@github.com/me/repo.git")).to eq(["me", "repo"])
      expect(described_class.parse_github_owner_repo("ssh://git@github.com/me/repo.git")).to eq(["me", "repo"])
      expect(described_class.parse_github_owner_repo("https://github.com/me/repo")).to eq(["me", "repo"])
    end

    it "github_remote_candidates filters by github.com" do
      allow(described_class).to receive(:remotes_with_urls).and_return({
        "origin" => "https://gitlab.com/me/repo.git",
        "gh" => "git@github.com:me/repo.git",
        "cb" => "https://codeberg.org/me/repo.git"
      })
      expect(described_class.github_remote_candidates).to eq(["gh"])
    end

    it "gitlab_remote_candidates filters by gitlab.com" do
      allow(described_class).to receive(:remotes_with_urls).and_return({
        "origin" => "https://github.com/me/repo.git",
        "gl" => "git@gitlab.com:me/repo.git",
        "cb" => "https://codeberg.org/me/repo.git"
      })
      expect(described_class.gitlab_remote_candidates).to eq(["gl"])
    end
  end

  describe "wrappers around GitAdapter" do
    it "delegates remotes_with_urls and remote_url" do
      fake = instance_double(Kettle::Dev::GitAdapter)
      allow(Kettle::Dev::GitAdapter).to receive(:new).and_return(fake)
      allow(fake).to receive(:remotes_with_urls).and_return({"origin" => "https://github.com/acme/demo.git"})
      allow(fake).to receive(:remote_url).with("origin").and_return("https://github.com/acme/demo.git")
      expect(described_class.remotes_with_urls).to eq({"origin" => "https://github.com/acme/demo.git"})
      expect(described_class.remote_url("origin")).to eq("https://github.com/acme/demo.git")
    end
  end

  describe "::monitor_all! no CI configured" do
    it "aborts when neither GitHub nor GitLab present" do
      allow(helpers).to receive_messages(project_root: Dir.pwd, workflows_list: [], current_branch: "feat")
      allow(described_class).to receive_messages(preferred_github_remote: nil, gitlab_remote_candidates: [])
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(false)
      expect { described_class.monitor_all!(restart_hint: "hint") }.to raise_error(MockSystemExit, /CI configuration not detected/)
    end
  end

  describe "::monitor_and_prompt_for_release!" do
    before do
      # Simulate presence of failed checks so the prompt is reached
      allow(described_class).to receive(:collect_all).and_return({
        github: [
          {workflow: "ci.yml", status: "completed", conclusion: "failure", url: "https://example"}
        ],
        gitlab: nil
      })
      # TTY environment
      allow($stdin).to receive(:tty?).and_return(true)
    end

    it "continues once when user enters c", :check_output do
      allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("c\n")
      expect { described_class.monitor_and_prompt_for_release!(restart_hint: "hint") }.not_to raise_error
    end

    it "aborts when user enters q" do
      allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("q\n")
      expect { described_class.monitor_and_prompt_for_release!(restart_hint: "hint") }.to raise_error(MockSystemExit, /Aborting per user choice/)
    end

    it "aborts when input is nil (no input available)" do
      allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return(nil)
      expect { described_class.monitor_and_prompt_for_release!(restart_hint: "hint") }.to raise_error(MockSystemExit, /no input available/)
    end

    it "aborts on unrecognized input (single prompt)" do
      allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("maybe\n")
      expect { described_class.monitor_and_prompt_for_release!(restart_hint: "hint") }.to raise_error(MockSystemExit, /Unrecognized input/)
    end

    it "skips prompt in non-interactive when K_RELEASE_CI_CONTINUE=true", :check_output do
      stub_env("K_RELEASE_CI_CONTINUE" => "true")
      allow($stdin).to receive(:tty?).and_return(false)
      expect { described_class.monitor_and_prompt_for_release!(restart_hint: "hint") }.not_to raise_error
    end

    it "aborts in non-interactive when K_RELEASE_CI_CONTINUE not set" do
      stub_env("K_RELEASE_CI_CONTINUE" => nil)
      allow($stdin).to receive(:tty?).and_return(false)
      expect { described_class.monitor_and_prompt_for_release!(restart_hint: "hint") }.to raise_error(MockSystemExit, /CI checks reported failures/)
    end
  end

  describe "::collect_all" do
    it "handles exceptions from collectors and still returns results hash" do
      # Force collect_github to raise, collect_gitlab to return nil
      allow(described_class).to receive(:collect_github).and_raise(StandardError.new("boom"))
      allow(described_class).to receive(:collect_gitlab).and_return(nil)
      # Stub debug_error to avoid noisy output but assert it is called
      allow(Kettle::Dev).to receive(:debug_error)

      res = described_class.collect_all
      expect(res).to be_a(Hash)
      expect(res[:github]).to be_empty # default
      expect(res[:gitlab]).to be_nil
      expect(Kettle::Dev).to have_received(:debug_error).at_least(:once)
    end

    it "populates keys when collectors return values" do
      gh = [{workflow: "ci.yml", status: "completed", conclusion: "success", url: "https://x"}]
      gl = {status: "success", url: "https://gitlab.com/x/y/-/pipelines"}
      allow(described_class).to receive_messages(
        collect_github: gh,
        collect_gitlab: gl
      )
      res = described_class.collect_all
      expect(res[:github]).to eq(gh)
      expect(res[:gitlab]).to eq(gl)
    end
  end

  describe "::summarize_results" do
    it "prints GitHub and GitLab summaries and returns true when ok", :check_output do
      res = {
        github: [
          {workflow: "ci.yml", status: "completed", conclusion: "success", url: "https://example"}
        ],
        gitlab: {status: "success", url: "https://gitlab.com/me/repo/-/pipelines"}
      }
      expect(described_class.summarize_results(res)).to be true
    end

    it "returns false when GitLab failed", :check_output do
      res = {
        github: [],
        gitlab: {status: "failed", url: nil}
      }
      expect(described_class.summarize_results(res)).to be false
    end

    it "handles nil gitlab and empty github", :check_output do
      res = {github: [], gitlab: nil}
      expect(described_class.summarize_results(res)).to be true
    end
  end

  describe "::collect_github" do
    it "returns nil when no gh remote or workflows" do
      allow(helpers).to receive_messages(project_root: Dir.pwd, workflows_list: [])
      allow(described_class).to receive(:preferred_github_remote).and_return(nil)
      expect(described_class.collect_github).to be_nil
    end

    it "collects success and failure runs without aborting", :check_output do
      allow(helpers).to receive_messages(project_root: Dir.pwd, workflows_list: ["ci.yml", "lint.yml"], current_branch: "main")
      allow(described_class).to receive(:preferred_github_remote).and_return("origin")
      allow(described_class).to receive_messages(remote_url: "https://github.com/me/repo.git", parse_github_owner_repo: ["me", "repo"])

      # First workflow succeeds, second fails
      runs = {
        "ci.yml" => {"status" => "completed", "conclusion" => "success", "html_url" => "https://github.com/me/repo/actions/runs/1"},
        "lint.yml" => {"status" => "completed", "conclusion" => "failure", "html_url" => nil}
      }
      allow(helpers).to receive(:latest_run) do |owner:, repo:, workflow_file:, branch:|
        runs[workflow_file]
      end
      allow(helpers).to receive(:success?) { |run| run["conclusion"] == "success" }
      allow(helpers).to receive(:failed?) { |run| run["conclusion"] == "failure" }

      res = described_class.collect_github
      expect(res).to contain_exactly(
        include(workflow: "ci.yml", conclusion: "success", url: "https://github.com/me/repo/actions/runs/1"),
        include(workflow: "lint.yml", conclusion: "failure", url: "https://github.com/me/repo/actions/workflows/lint.yml")
      )
    end

    it "respects K_RELEASE_CI_INITIAL_SLEEP when set" do
      allow(helpers).to receive_messages(project_root: Dir.pwd, workflows_list: ["ci.yml"], current_branch: "main")
      allow(described_class).to receive_messages(preferred_github_remote: "origin", remote_url: "https://github.com/me/repo.git", parse_github_owner_repo: ["me", "repo"])
      allow(helpers).to receive_messages(latest_run: {"status" => "completed", "conclusion" => "success", "html_url" => "https://x"}, success?: true)

      # Set env to 0 to avoid real delay (do not modify ENV directly in specs)
      stub_env("K_RELEASE_CI_INITIAL_SLEEP" => "0")
      expect { described_class.collect_github }.not_to raise_error
    end
  end

  describe "::collect_gitlab" do
    it "returns nil when not configured" do
      allow(helpers).to receive(:project_root).and_return(Dir.pwd)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(false)
      allow(described_class).to receive_messages(gitlab_remote_candidates: [])
      expect(described_class.collect_gitlab).to be_nil
    end

    it "returns success result when pipeline succeeds", :check_output do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive_messages(gitlab_remote_candidates: ["gl"])
      pipe = {"status" => "success", "web_url" => "https://gitlab.com/me/repo/-/pipelines/9"}
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat", repo_info_gitlab: ["me", "repo"], gitlab_latest_pipeline: pipe, gitlab_success?: true)
      res = described_class.collect_gitlab
      expect(res[:status]).to eq("success")
      expect(res[:url]).to eq("https://gitlab.com/me/repo/-/pipelines/9")
    end

    it "returns failed result when pipeline fails normally" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive_messages(gitlab_remote_candidates: ["gl"])
      pipe = {"status" => "failed", "web_url" => nil, "failure_reason" => "script_failure"}
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat", repo_info_gitlab: ["me", "repo"], gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: true)
      res = described_class.collect_gitlab
      expect(res[:status]).to eq("failed")
      expect(res[:url]).to eq("https://gitlab.com/me/repo/-/pipelines")
    end

    it "returns unknown when minutes/quota exhausted" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive_messages(gitlab_remote_candidates: ["gl"])
      pipe = {"status" => "failed", "web_url" => nil, "failure_reason" => "insufficient minutes"}
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat", repo_info_gitlab: ["me", "repo"], gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: true)
      res = described_class.collect_gitlab
      expect(res[:status]).to eq("unknown")
    end

    it "returns blocked when pipeline status is blocked" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
      allow(described_class).to receive_messages(gitlab_remote_candidates: ["gl"])
      pipe = {"status" => "blocked", "web_url" => nil}
      allow(helpers).to receive_messages(project_root: Dir.pwd, current_branch: "feat", repo_info_gitlab: ["me", "repo"], gitlab_latest_pipeline: pipe, gitlab_success?: false, gitlab_failed?: false)
      res = described_class.collect_gitlab
      expect(res[:status]).to eq("blocked")
    end
  end
end
