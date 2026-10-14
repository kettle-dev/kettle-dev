# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Kettle::Dev::CIHelpers do
  describe "::<module_function> availability" do
    it "responds to expected methods" do
      %i[
        project_root
        repo_info
        current_branch
        workflows_list
        exclusions
        latest_run
        success?
        failed?
        default_token
        origin_url
        repo_info_gitlab
        default_gitlab_token
        gitlab_latest_pipeline
        gitlab_success?
        gitlab_failed?
      ].each do |m|
        expect(described_class).to respond_to(m)
      end
    end
  end

  describe "::project_root" do
    it "uses Rake.application.original_dir when available" do
      original = Dir.pwd
      fake_root = Dir.mktmpdir("proj")
      begin
        rake = double("RakeApp", original_dir: fake_root)
        stub_const("Rake", double("Rake", application: rake))
        expect(described_class.project_root).to eq(fake_root)
      ensure
        Dir.chdir(original) # rubocop:disable ThreadSafety/DirChdir
        FileUtils.remove_entry(fake_root)
      end
    end

    it "falls back to Dir.pwd when Rake is not available" do
      hide_const("Rake") if defined?(Rake)
      expect(described_class.project_root).to eq(Dir.pwd)
    end
  end

  describe "::repo_info" do
    it "parses SSH origin URL" do
      allow(Open3).to receive(:capture2).and_return([
        "git@github.com:owner/repo.git\n",
        instance_double(Process::Status, success?: true)
      ])
      expect(described_class.repo_info).to eq(["owner", "repo"])
    end

    it "parses git+ssh origin URL" do
      allow(Open3).to receive(:capture2).and_return([
        "git+ssh://git@github.com/owner/repo.git\n",
        instance_double(Process::Status, success?: true)
      ])
      expect(described_class.repo_info).to eq(["owner", "repo"])
    end

    it "parses ssh origin URL" do
      allow(Open3).to receive(:capture2).and_return([
        "ssh://git@github.com/owner/repo.git\n",
        instance_double(Process::Status, success?: true)
      ])
      expect(described_class.repo_info).to eq(["owner", "repo"])
    end

    it "parses HTTPS origin URL" do
      allow(Open3).to receive(:capture2).and_return([
        "https://github.com/owner/repo\n",
        instance_double(Process::Status, success?: true)
      ])
      expect(described_class.repo_info).to eq(["owner", "repo"])
    end

    it "returns nil when git command fails" do
      allow(Open3).to receive(:capture2).and_return(["", instance_double(Process::Status, success?: false)])
      expect(described_class.repo_info).to be_nil
    end

    it "returns nil when origin is non-GitHub" do
      allow(Open3).to receive(:capture2).and_return([
        "git@gitlab.com:owner/repo.git\n",
        instance_double(Process::Status, success?: true)
      ])
      expect(described_class.repo_info).to be_nil
    end
  end

  describe "::current_branch" do
    it "returns branch when command succeeds" do
      allow(Open3).to receive(:capture2).and_return([
        "main\n",
        instance_double(Process::Status, success?: true)
      ])
      expect(described_class.current_branch).to eq("main")
    end

    it "returns nil on failure" do
      allow(Open3).to receive(:capture2).and_return(["", instance_double(Process::Status, success?: false)])
      expect(described_class.current_branch).to be_nil
    end
  end

  describe "::workflows_list" do
    it "lists .yml and .yaml files and excludes maintenance ones" do
      Dir.mktmpdir("root") do |root|
        dir = File.join(root, ".github", "workflows")
        FileUtils.mkdir_p(dir)
        %w[ci.yml style.yaml codeql-analysis.yml dependency-review.yml scorecard-analysis.yml].each do |f|
          File.write(File.join(dir, f), "name: test\n")
        end
        list = described_class.workflows_list(root)
        expect(list).to include("ci.yml", "style.yaml")
        expect(list).not_to include("codeql-analysis.yml", "dependency-review.yml", "scorecard-analysis.yml")
      end
    end

    it "returns [] when dir missing" do
      Dir.mktmpdir("root") do |root|
        expect(described_class.workflows_list(root)).to be_empty
      end
    end
  end

  describe "::latest_run / ::success? / ::failed?" do
    let(:owner) { "owner" }
    let(:repo) { "repo" }
    let(:workflow) { "ci.yml" }
    let(:branch) { "main" }

    before do
      allow(described_class).to receive(:current_branch).and_return(branch)
    end

    def http_response(body:, code: "200")
      if code == "200"
        instance_double(Net::HTTPOK, is_a?: true, body: body, code: code)
      elsif code == "401"
        Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      else
        begin
          r = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
          r["X-RateLimit-Remaining"] = "0"
          r["X-RateLimit-Reset"] = (Time.now.utc + 60).to_i.to_s
          r
        end
      end
    end

    def stub_http_capture_authorization(body:)
      captured = {auth: :unset}
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request) do |req|
        captured[:auth] = req["Authorization"]
        http_response(body: JSON.dump(body))
      end
      allow(Net::HTTP).to receive(:start).and_yield(http)
      captured
    end

    it "returns hash for successful API with a run" do
      data = {"workflow_runs" => [{"status" => "completed", "conclusion" => "success", "html_url" => "https://x/y", "id" => 1}]}
      allow(Net::HTTP).to receive(:start).and_return(http_response(body: JSON.dump(data)))
      run = described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)
      expect(run).to include("status" => "completed", "conclusion" => "success")
      expect(described_class.success?(run)).to be(true)
      expect(described_class.failed?(run)).to be(false)
    end

    it "returns nil when API returns no runs" do
      data = {"workflow_runs" => []}
      allow(Net::HTTP).to receive(:start).and_return(http_response(body: JSON.dump(data)))
      expect(described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)).to be_nil
    end

    it "raises CIAuthError on 401 so the monitor aborts instead of ticking forever" do
      allow(Net::HTTP).to receive(:start).and_return(http_response(body: "{}", code: "401"))
      expect {
        described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)
      }.to raise_error(Kettle::Dev::CIAuthError, /invalid or revoked token/)
    end

    it "raises CIRateLimitError on 403 with exhausted quota" do
      allow(Net::HTTP).to receive(:start).and_return(http_response(body: "{}", code: "403"))
      expect {
        described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)
      }.to raise_error(Kettle::Dev::CIRateLimitError, /rate limit exceeded/)
    end

    it "does not raise on non-quota 403 (treats as no data)" do
      allow(Net::HTTP).to receive(:start).and_return(
        begin
          r = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
          r["X-RateLimit-Remaining"] = "4999"
          r["X-RateLimit-Reset"] = (Time.now.utc + 60).to_i.to_s
          r
        end
      )
      expect(described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)).to be_nil
    end

    it "returns nil when API returns no workflow_runs key" do
      data = {"something_else" => []}
      allow(Net::HTTP).to receive(:start).and_return(http_response(body: JSON.dump(data)))
      expect(described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)).to be_nil
    end

    it "returns nil on HTTP failure" do
      bad = instance_double(Net::HTTPBadRequest, is_a?: false, code: "400", body: "")
      allow(Net::HTTP).to receive(:start).and_return(bad)
      expect(described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)).to be_nil
    end

    it "returns nil when owner/repo missing" do
      expect(described_class.latest_run(owner: nil, repo: repo, workflow_file: workflow, branch: branch)).to be_nil
    end

    it "returns nil when no branch available" do
      allow(described_class).to receive(:current_branch).and_return(nil)
      expect(described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow)).to be_nil
    end

    it "does not set Authorization header when token is empty" do
      data = {"workflow_runs" => [{"status" => "queued", "conclusion" => nil, "html_url" => "https://x/y", "id" => 2}]}
      cap = stub_http_capture_authorization(body: data)
      described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch, token: "")
      expect(cap[:auth]).to be_nil
    end

    it "sets Authorization header when token provided" do
      data = {"workflow_runs" => [{"status" => "completed", "conclusion" => "success", "html_url" => "https://x/y", "id" => 3}]}
      cap = stub_http_capture_authorization(body: data)
      described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch, token: "SECRET")
      expect(cap[:auth]).to eq("token SECRET")
    end

    it "failed? is true for completed non-success" do
      run = {"status" => "completed", "conclusion" => "failure"}
      expect(described_class.failed?(run)).to be(true)
    end

    it "success? returns false for nil run" do
      expect(described_class).not_to be_success(nil)
    end

    it "failed? returns false for nil run" do
      expect(described_class).not_to be_failed(nil)
    end

    it "success? returns false when conclusion is nil" do
      run = {"status" => "completed", "conclusion" => nil}
      expect(described_class).not_to be_success(run)
    end

    it "failed? returns false when conclusion is nil" do
      run = {"status" => "completed", "conclusion" => nil}
      expect(described_class).not_to be_failed(run)
    end

    it "returns nil when an exception occurs (rescued)" do
      allow(Net::HTTP).to receive(:start).and_raise(StandardError.new("boom"))
      expect(
        described_class.latest_run(owner: owner, repo: repo, workflow_file: workflow, branch: branch)
      ).to be_nil
    end
  end

  describe "::default_token" do
    it "prefers GITHUB_TOKEN then GH_TOKEN" do
      stub_env("GITHUB_TOKEN" => "aaa", "GH_TOKEN" => "bbb")
      expect(described_class.default_token).to eq("aaa")
      stub_env("GITHUB_TOKEN" => nil, "GH_TOKEN" => "bbb")
      expect(described_class.default_token).to eq("bbb")
      stub_env("GITHUB_TOKEN" => nil, "GH_TOKEN" => nil)
      expect(described_class.default_token).to be_nil
    end
  end

  # --- New: GitLab helpers ---
  describe "GitLab helpers" do
    describe "::origin_url" do
      it "returns origin url when config succeeds" do
        allow(Open3).to receive(:capture2).and_return([
          "git@gitlab.com:owner/repo.git\n",
          instance_double(Process::Status, success?: true)
        ])
        expect(described_class.origin_url).to eq("git@gitlab.com:owner/repo.git")
      end

      it "returns nil when config fails" do
        allow(Open3).to receive(:capture2).and_return(["", instance_double(Process::Status, success?: false)])
        expect(described_class.origin_url).to be_nil
      end
    end

    describe "::repo_info_gitlab" do
      it "parses SSH origin URL" do
        allow(described_class).to receive(:origin_url).and_return("git@gitlab.com:group/proj.git")
        expect(described_class.repo_info_gitlab).to eq(["group", "proj"])
      end

      it "parses git+ssh origin URL" do
        allow(described_class).to receive(:origin_url).and_return("git+ssh://git@gitlab.com/group/proj.git")
        expect(described_class.repo_info_gitlab).to eq(["group", "proj"])
      end

      it "parses HTTPS origin URL" do
        allow(described_class).to receive(:origin_url).and_return("https://gitlab.com/group/proj")
        expect(described_class.repo_info_gitlab).to eq(["group", "proj"])
      end

      it "returns nil when origin is not gitlab" do
        allow(described_class).to receive(:origin_url).and_return("git@github.com:owner/repo.git")
        expect(described_class.repo_info_gitlab).to be_nil
      end
    end

    describe "::default_gitlab_token" do
      it "uses GITLAB_TOKEN when present" do
        stub_env("GITLAB_TOKEN" => "ggg", "GL_TOKEN" => "lll")
        expect(described_class.default_gitlab_token).to eq("ggg")
      end

      it "falls back to GL_TOKEN when GITLAB_TOKEN missing" do
        stub_env("GITLAB_TOKEN" => nil, "GL_TOKEN" => "lll")
        expect(described_class.default_gitlab_token).to eq("lll")
      end

      it "returns nil when neither token is present" do
        stub_env("GITLAB_TOKEN" => nil, "GL_TOKEN" => nil)
        expect(described_class.default_gitlab_token).to be_nil
      end
    end

    describe "::gitlab_latest_pipeline / ::gitlab_success? / ::gitlab_failed?" do
      let(:owner) { "grp" }
      let(:repo) { "proj" }
      let(:branch) { "main" }

      before do
        allow(described_class).to receive(:current_branch).and_return(branch)
      end

      def gitlab_http_ok(body:)
        instance_double(Net::HTTPOK, is_a?: true, body: JSON.dump(body))
      end

      def stub_http_capture_private_token(body:)
        captured = {token: :unset}
        http = instance_double(Net::HTTP)
        allow(http).to receive(:request) do |req|
          captured[:token] = req["PRIVATE-TOKEN"]
          gitlab_http_ok(body: body)
        end
        allow(Net::HTTP).to receive(:start).and_yield(http)
        captured
      end

      it "returns hash for successful API with a pipeline" do
        data = [{"status" => "success", "web_url" => "https://gitlab.com/x/y/-/pipelines/1", "id" => 1}]
        allow(Net::HTTP).to receive(:start).and_return(gitlab_http_ok(body: data))
        pipe = described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
        expect(pipe).to include("status" => "success", "id" => 1)
      end

      it "classifies the returned pipeline as success" do
        data = [{"status" => "success", "web_url" => "https://gitlab.com/x/y/-/pipelines/1", "id" => 1}]
        allow(Net::HTTP).to receive(:start).and_return(gitlab_http_ok(body: data))
        pipe = described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
        expect(described_class.gitlab_success?(pipe)).to be(true)
      end

      it "does not classify the returned pipeline as failed" do
        data = [{"status" => "success", "web_url" => "https://gitlab.com/x/y/-/pipelines/1", "id" => 1}]
        allow(Net::HTTP).to receive(:start).and_return(gitlab_http_ok(body: data))
        pipe = described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
        expect(described_class.gitlab_failed?(pipe)).to be(false)
      end

      it "returns nil when API returns empty array" do
        data = []
        allow(Net::HTTP).to receive(:start).and_return(gitlab_http_ok(body: data))
        expect(described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)).to be_nil
      end

      it "returns nil when API returns a JSON object (non-array) despite HTTP 200" do
        body = {"message" => "401 Unauthorized"}
        allow(Net::HTTP).to receive(:start).and_return(gitlab_http_ok(body: body))
        expect(described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)).to be_nil
      end

      it "returns nil when API returns a JSON string (non-array) despite HTTP 200" do
        body = "some unexpected string"
        allow(Net::HTTP).to receive(:start).and_return(gitlab_http_ok(body: body))
        expect(described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)).to be_nil
      end

      it "returns nil on HTTP failure" do
        bad = instance_double(Net::HTTPBadRequest, is_a?: false, code: "400", body: "")
        allow(Net::HTTP).to receive(:start).and_return(bad)
        expect(described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)).to be_nil
      end

      it "returns nil when owner/repo missing" do
        expect(described_class.gitlab_latest_pipeline(owner: nil, repo: repo, branch: branch)).to be_nil
      end

      it "returns nil when no branch available" do
        allow(described_class).to receive(:current_branch).and_return(nil)
        expect(described_class.gitlab_latest_pipeline(owner: owner, repo: repo)).to be_nil
      end

      it "does not set PRIVATE-TOKEN header when token is empty" do
        data = [{"status" => "pending", "web_url" => "https://x/y", "id" => 2}]
        cap = stub_http_capture_private_token(body: data)
        described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch, token: "")
        expect(cap[:token]).to be_nil
      end

      it "sets PRIVATE-TOKEN header when token provided" do
        data = [{"status" => "success", "web_url" => "https://x/y", "id" => 3}]
        cap = stub_http_capture_private_token(body: data)
        described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch, token: "SEKRET")
        expect(cap[:token]).to eq("SEKRET")
      end

      it "gitlab_success? returns true for status=success" do
        expect(described_class.gitlab_success?({"status" => "success"})).to be(true)
      end

      it "gitlab_success? returns false for non-success status" do
        expect(described_class.gitlab_success?({"status" => "failed"})).to be(false)
      end

      it "gitlab_success? returns false for nil" do
        expect(described_class).not_to be_gitlab_success(nil)
      end

      it "gitlab_failed? returns true for status=failed" do
        expect(described_class.gitlab_failed?({"status" => "failed"})).to be(true)
      end

      it "gitlab_failed? returns false for non-failed status" do
        expect(described_class.gitlab_failed?({"status" => "success"})).to be(false)
      end

      it "gitlab_failed? returns false for nil" do
        expect(described_class).not_to be_gitlab_failed(nil)
      end

      it "returns nil when an exception occurs (rescued)" do
        allow(Net::HTTP).to receive(:start).and_raise(StandardError.new("boom"))
        expect(
          described_class.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
        ).to be_nil
      end
    end
  end

  describe "::latest_run head_sha filtering" do
    it "falls back to first run when HEAD sha is unavailable" do
      allow(described_class).to receive(:current_branch).and_return("main")
      # Simulate failure to read HEAD sha
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["", instance_double(Process::Status, success?: false)])

      body = {
        "workflow_runs" => [
          {"id" => 10, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/first", "head_sha" => "zzz"},
          {"id" => 20, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/second", "head_sha" => "abc"}
        ]
      }.to_json

      response = instance_double(Net::HTTPSuccess, body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(response)
      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil)
      expect(run).to include("id" => 10, "html_url" => "https://x/first")
    end

    it "prefers the run matching HEAD sha over older runs on the same branch" do
      # Stub current branch and HEAD sha
      allow(described_class).to receive(:current_branch).and_return("main")
      # Simulate `git rev-parse HEAD`
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["abc123\n", instance_double(Process::Status, success?: true)])

      # Build a fake GitHub API response with two runs: first is older (different sha), second matches HEAD
      body = {
        "workflow_runs" => [
          {"id" => 100, "status" => "completed", "conclusion" => "failure", "html_url" => "https://x/older", "head_sha" => "zzz999"},
          {"id" => 200, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/newer", "head_sha" => "abc123"}
        ]
      }.to_json

      response = instance_double(Net::HTTPSuccess, body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      http = instance_double(Net::HTTP)
      # Stub a GET request
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(response)

      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil)
      expect(run).to include("id" => 200, "html_url" => "https://x/newer")
    end

    it "prefers a non-cancelled duplicate run for the same HEAD sha" do
      allow(described_class).to receive(:current_branch).and_return("main")
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["abc123\n", instance_double(Process::Status, success?: true)])

      body = {
        "workflow_runs" => [
          {"id" => 100, "status" => "completed", "conclusion" => "cancelled", "html_url" => "https://x/cancelled", "head_sha" => "abc123"},
          {"id" => 200, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/success", "head_sha" => "abc123"}
        ]
      }.to_json

      response = instance_double(Net::HTTPSuccess, body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(response)
      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil)
      expect(run).to include("id" => 200, "html_url" => "https://x/success")
    end

    it "selects the newest matching run even when GitHub returns it after an older failure" do
      allow(described_class).to receive(:current_branch).and_return("main")
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["abc123\n", instance_double(Process::Status, success?: true)])

      body = {
        "workflow_runs" => [
          {
            "id" => 100,
            "run_number" => 40,
            "run_attempt" => 1,
            "status" => "completed",
            "conclusion" => "failure",
            "created_at" => "2026-08-07T20:00:00Z",
            "updated_at" => "2026-08-07T20:01:00Z",
            "html_url" => "https://x/older",
            "head_sha" => "abc123"
          },
          {
            "id" => 101,
            "run_number" => 41,
            "run_attempt" => 1,
            "status" => "completed",
            "conclusion" => "success",
            "created_at" => "2026-08-07T20:02:00Z",
            "updated_at" => "2026-08-07T20:03:00Z",
            "html_url" => "https://x/newer",
            "head_sha" => "abc123"
          }
        ]
      }.to_json

      response = instance_double(Net::HTTPSuccess, body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(response)
      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil)
      expect(run).to include("id" => 101, "html_url" => "https://x/newer")
    end

    it "uses updated_at to select the latest rerun of an existing workflow run" do
      allow(described_class).to receive(:current_branch).and_return("main")
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["abc123\n", instance_double(Process::Status, success?: true)])

      body = {
        "workflow_runs" => [
          {
            "id" => 100,
            "run_number" => 40,
            "run_attempt" => 1,
            "status" => "completed",
            "conclusion" => "failure",
            "created_at" => "2026-08-07T20:00:00Z",
            "updated_at" => "2026-08-07T20:01:00Z",
            "html_url" => "https://x/failed",
            "head_sha" => "abc123"
          },
          {
            "id" => 100,
            "run_number" => 40,
            "run_attempt" => 2,
            "status" => "completed",
            "conclusion" => "success",
            "created_at" => "2026-08-07T20:00:00Z",
            "updated_at" => "2026-08-07T20:04:00Z",
            "html_url" => "https://x/rerun",
            "head_sha" => "abc123"
          }
        ]
      }.to_json

      response = instance_double(Net::HTTPSuccess, body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(response)
      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil)
      expect(run).to include("id" => 100, "html_url" => "https://x/rerun", "conclusion" => "success")
    end

    it "returns nil instead of falling back when exact HEAD is required and no run has started" do
      allow(described_class).to receive(:current_branch).and_return("main")
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["abc123\n", instance_double(Process::Status, success?: true)])

      body = {
        "workflow_runs" => [
          {"id" => 100, "status" => "completed", "conclusion" => "failure", "html_url" => "https://x/older", "head_sha" => "zzz999"}
        ]
      }.to_json

      response = instance_double(Net::HTTPSuccess, body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(response)
      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil, require_head: true)
      expect(run).to be_nil
    end

    it "falls back to repository runs when the workflow endpoint lags for the exact HEAD" do
      allow(described_class).to receive(:current_branch).and_return("main")
      allow(Open3).to receive(:capture2).with("git", "rev-parse", "HEAD").and_return(["abc123\n", instance_double(Process::Status, success?: true)])

      workflow_body = {
        "workflow_runs" => [
          {"id" => 100, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/older", "head_sha" => "zzz999", "path" => ".github/workflows/ci.yml"}
        ]
      }.to_json
      repository_body = {
        "workflow_runs" => [
          {"id" => 200, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/newer", "head_sha" => "abc123", "path" => ".github/workflows/ci.yml"},
          {"id" => 300, "status" => "completed", "conclusion" => "success", "html_url" => "https://x/other", "head_sha" => "abc123", "path" => ".github/workflows/other.yml"}
        ]
      }.to_json
      workflow_response = instance_double(Net::HTTPSuccess, body: workflow_body)
      repository_response = instance_double(Net::HTTPSuccess, body: repository_body)
      allow(workflow_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(repository_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(workflow_response, repository_response)
      allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

      run = described_class.latest_run(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "main", token: nil, require_head: true)
      expect(run).to include("id" => 200, "html_url" => "https://x/newer")
    end
  end

  # Consolidated from ci_helpers_extra_spec.rb: enrich details from GitLab
  describe "::gitlab_latest_pipeline enrichment" do
    it "enriches pipeline with detail fields when available" do
      # First call returns list with one pipeline id
      list_body = [{"id" => 42, "status" => "running"}].to_json
      list_resp = instance_double(Net::HTTPSuccess, body: list_body)
      allow(list_resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      # Second call returns detail with failure_reason, status, and web_url
      det_body = {"id" => 42, "status" => "failed", "web_url" => "https://gitlab.com/me/repo/-/pipelines/42", "failure_reason" => "script_failure"}.to_json
      det_resp = instance_double(Net::HTTPSuccess, body: det_body)
      allow(det_resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      # Net::HTTP.start is called twice; first returns list, second returns detail
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(list_resp)
      http2 = instance_double(Net::HTTP)
      allow(http2).to receive(:request).with(instance_of(Net::HTTP::Get)).and_return(det_resp)

      calls = 0
      allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &blk|
        obj = calls.zero? ? http : http2
        calls += 1
        blk.call(obj)
      end

      allow(described_class).to receive(:current_branch).and_return("main")
      result = described_class.gitlab_latest_pipeline(owner: "me", repo: "repo")
      expect(result).to include(
        "id" => 42,
        "status" => "failed",
        "web_url" => "https://gitlab.com/me/repo/-/pipelines/42",
        "failure_reason" => "script_failure"
      )
    end
  end

  describe ".github_rate_limit_wait! (ticket limiter)" do
    let(:interval) { described_class::CI_RATE_MIN_INTERVAL }

    around do |example|
      Dir.mktmpdir("ci_rate_ledger_") do |dir|
        @ledger = File.join(dir, "ledger.json")
        example.run
      end
    end

    before do
      stub_env("K_RELEASE_CI_RATE_STATE_FILE" => @ledger)
    end

    def read_ledger
      JSON.parse(File.read(@ledger))
    end

    it "points the ledger at the env override read at call time" do
      expect(described_class.ci_rate_state_path).to eq(@ledger)
    end

    it "claims consecutive slots one interval apart" do
      first = described_class.claim_ci_rate_slot
      second = described_class.claim_ci_rate_slot

      expect(first).to eq(0.0)
      expect(second).to be_within(0.05).of(interval)
      slots = read_ledger["next_slot"]
      expect(slots).to be > Time.now.to_f # second claim reserved a future slot
    end

    it "does not hold the flock while the claimed wait is outstanding" do
      # Regression for the in-lock sleep: seed a future slot, claim (which
      # reserves an even later slot), and prove another process can take the
      # exclusive flock immediately — i.e. the waiter sleeps OUTSIDE the lock.
      future = Time.now.to_f + 30
      File.write(@ledger, JSON.generate({"next_slot" => future}))

      wait = described_class.claim_ci_rate_slot

      expect(wait).to be > 25
      File.open(@ledger, File::RDWR) do |probe|
        expect(probe.flock(File::LOCK_EX | File::LOCK_NB)).to eq(0)
      end
    end

    it "resets absurdly future ledger entries (clock skew)" do
      File.write(@ledger, JSON.generate({"next_slot" => Time.now.to_f + 7200}))

      expect(described_class.claim_ci_rate_slot).to eq(0.0)
    end

    it "keeps legitimately queued future slots (the ticket queue)" do
      soon = Time.now.to_f + 0.2
      File.write(@ledger, JSON.generate({"next_slot" => soon}))

      wait = described_class.claim_ci_rate_slot

      expect(wait).to be_within(0.15).of(0.2 + interval)
    end

    it "spaces every slot at least one interval apart under thread hammering" do
      slots = []
      threads = 8.times.map do
        Thread.new do # rubocop:disable ThreadSafety/NewThread -- the hammering scenario is the point: concurrent claimers must serialize through the flock without wedging
          10.times { slots << described_class.claim_ci_rate_slot }
        end
      end
      threads.each(&:join)

      # 80 claims against one ledger: the waits handed out must be distinct
      # reserved offsets — 0 for the first, then one interval apart — which is
      # only possible if every claim serialized through the flock correctly.
      waits = slots.sort
      expect(waits.first).to eq(0.0)
      waits.each_cons(2) do |a, b|
        expect(b - a).to be > interval * 0.5
      end
    end

    it "spaces slots across separate OS processes (the production scenario)" do
      script = <<~RUBY
        $LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))
        require "kettle/dev/ci_helpers"
        20.times { Kettle::Dev::CIHelpers.claim_ci_rate_slot }
        puts "done"
      RUBY
      3.times do
        # stub_env is in-process only; the child needs the real env var.
        `K_RELEASE_CI_RATE_STATE_FILE=#{Shellwords.escape(@ledger)} #{Gem.ruby} -e #{Shellwords.escape(script)} 2>&1`
      end
      # Subprocess claims must have reserved 60 strictly spaced future slots.
      final_slot = read_ledger["next_slot"]
      expect(final_slot - Time.now.to_f).to be > 50 * interval
    end

    it "in-process fallback reserves spaced slots" do
      described_class.instance_variable_set(:@ci_rate_inproc_last, 0.0)
      begin
        first = described_class.ci_rate_claim_in_process
        second = described_class.ci_rate_claim_in_process

        expect(first).to eq(0.0)
        expect(second).to be_within(0.05).of(interval)
      ensure
        described_class.instance_variable_set(:@ci_rate_inproc_last, 0.0)
      end
    end
  end
end
