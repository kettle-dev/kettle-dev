# frozen_string_literal: true

require "open3"

RSpec.describe Kettle::Dev::Rebase do
  around do |example|
    Dir.mktmpdir("kettle-rebase-spec") do |dir|
      @tmpdir = dir
      example.run
    end
  end

  it "skips when nested inside an outer kettle command" do
    stub_env("KETTLE_REBASE_NESTED" => "true")

    result = described_class.call(root: File.join(@tmpdir, "nonexistent"))

    expect(result.status).to eq(:skipped_nested)
    expect(result).to be_ok
  end

  it "treats falsey marker values as not nested" do
    stub_env("KETTLE_REBASE_NESTED" => "false")
    root = repo_with_origin("alpha")

    result = described_class.call(root: root)

    expect(result.status).to eq(:ok)
  end

  it "errors on a non-git directory" do
    root = File.join(@tmpdir, "plain")
    FileUtils.mkdir_p(root)

    result = described_class.call(root: root)

    expect(result.status).to eq(:error)
    expect(result).not_to be_ok
    expect(result.message).to include("not a git repository")
  end

  it "errors on a detached HEAD" do
    root = repo_with_origin("alpha")
    git(root, "checkout", "--detach")

    result = described_class.call(root: root)

    expect(result.status).to eq(:error)
    expect(result.message).to include("detached HEAD")
  end

  it "skips a branch with no upstream" do
    root = repo_with_origin("alpha")
    git(root, "switch", "-c", "local-only")

    result = described_class.call(root: root)

    expect(result.status).to eq(:skipped_no_upstream)
    expect(result).to be_ok
  end

  it "reports up to date when the branch matches its upstream" do
    root = repo_with_origin("alpha")

    result = described_class.call(root: root)

    expect(result.status).to eq(:ok)
    expect(result.behind).to eq(0)
    expect(result.message).to include("up to date")
  end

  it "rebases a branch that is behind upstream" do
    root = repo_with_origin("alpha")
    origin_tip = advance_origin("alpha")

    result = described_class.call(root: root)

    expect(result.status).to eq(:updated)
    expect(result.behind).to eq(1)
    expect(head(root)).to eq(origin_tip)
  end

  it "replays local commits when diverged" do
    root = repo_with_origin("alpha")
    File.write(File.join(root, "local.txt"), "local\n")
    git(root, "add", ".")
    git(root, "commit", "-qm", "local work")
    origin_tip = advance_origin("alpha")

    result = described_class.call(root: root)

    expect(result.status).to eq(:updated)
    expect(head(root)).not_to eq(origin_tip)
    expect(git_output(root, "log", "--oneline", "-2")).to include("local work", "upstream change")
  end

  it "aborts a conflicting rebase and restores the checkout to its pre-pull state" do
    root = repo_with_origin("alpha")
    File.write(File.join(root, "f.txt"), "local\n")
    git(root, "add", ".")
    git(root, "commit", "-qm", "local change to f")
    advance_origin("alpha", filename: "f.txt", content: "upstream\n")
    File.write(File.join(root, "g.txt"), "dirty\n")
    before = head(root)

    result = described_class.call(root: root)

    expect(result.status).to eq(:conflict)
    expect(result).not_to be_ok
    expect(result.conflicts).to eq(["f.txt"])
    expect(result.message).to include("f.txt", "restored")
    expect(head(root)).to eq(before)
    expect(File.read(File.join(root, "g.txt"))).to eq("dirty\n")
    expect(File.directory?(File.join(root, ".git", "rebase-merge"))).to be(false)
  end

  it "fails open when the upstream cannot be fetched" do
    root = repo_with_origin("alpha")
    FileUtils.rm_rf(File.join(@tmpdir, "alpha-origin.git"))

    result = described_class.call(root: root)

    expect(result.status).to eq(:skipped_unreachable)
    expect(result).to be_ok
  end

  it "preserves dirty worktree changes across a clean rebase" do
    root = repo_with_origin("alpha")
    advance_origin("alpha", filename: "other.txt", content: "upstream\n")
    File.write(File.join(root, "f.txt"), "dirty\n")

    result = described_class.call(root: root)

    expect(result.status).to eq(:updated)
    expect(File.read(File.join(root, "f.txt"))).to eq("dirty\n")
  end

  it "notes unpushed commits on an up-to-date branch and exposes synced?" do
    root = repo_with_origin("alpha")
    File.write(File.join(root, "local.txt"), "local\n")
    git(root, "add", ".")
    git(root, "commit", "-qm", "local work")

    result = described_class.call(root: root)

    expect(result.status).to eq(:ok)
    expect(result).not_to be_synced
    expect(result.ahead).to eq(1)
    expect(result.message).to include("ahead by 1")

    advance_origin("alpha")
    updated = described_class.call(root: root)
    expect(updated).to be_synced
  end

  it "errors cleanly when git is unavailable" do
    allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

    result = described_class.call(root: @tmpdir)

    expect(result.status).to eq(:error)
    expect(result.message).to include("not a git repository")
  end

  it "treats git failures in upstream and tip lookups as unknown" do
    allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

    expect(described_class.upstream_for(@tmpdir)).to be_nil
    expect(described_class.tip_state(@tmpdir)).to eq([nil, nil])
  end

  it "fails open when the tip comparison itself fails" do
    root = repo_with_origin("alpha")
    real = Open3.method(:capture3)
    allow(Open3).to receive(:capture3) do |*args, **kwargs|
      if args.include?("rev-list")
        ["", "boom", instance_double(Process::Status, success?: false)]
      else
        real.call(*args, **kwargs)
      end
    end

    result = described_class.call(root: root)

    expect(result.status).to eq(:skipped_unreachable)
  end

  it "reports a conflict without a file list when the conflict scan fails" do
    root = repo_with_origin("alpha")
    File.write(File.join(root, "f.txt"), "local\n")
    git(root, "add", ".")
    git(root, "commit", "-qm", "local change to f")
    advance_origin("alpha", filename: "f.txt", content: "upstream\n")
    real = Open3.method(:capture3)
    allow(Open3).to receive(:capture3) do |*args, **kwargs|
      if args.include?("--diff-filter=U")
        ["", "boom", instance_double(Process::Status, success?: false)]
      else
        real.call(*args, **kwargs)
      end
    end

    result = described_class.call(root: root)

    expect(result.status).to eq(:conflict)
    expect(result.conflicts).to be_empty
    expect(result.message).not_to include("conflicts:")
    expect(File.directory?(File.join(root, ".git", "rebase-merge"))).to be(false)
  end

  def git(root, *args)
    system("git", "-C", root, *args, out: File::NULL, err: File::NULL) || raise("git #{args.first} failed in #{root}")
  end

  def git_output(root, *args)
    stdout, status = Open3.capture2("git", "-C", root, *args)
    raise "git #{args.first} failed in #{root}" unless status.success?

    stdout
  end

  # A member clone of a fresh bare origin, on main, with one commit pushed
  # and upstream tracking set.
  def repo_with_origin(name)
    origin = File.join(@tmpdir, "#{name}-origin.git")
    system("git", "init", "-q", "--bare", "--initial-branch=main", origin, out: File::NULL, err: File::NULL) || raise("bare init failed")
    root = File.join(@tmpdir, name)
    system("git", "clone", "-q", origin, root, out: File::NULL, err: File::NULL) || raise("clone failed")
    git(root, "config", "user.email", "spec@example.test")
    git(root, "config", "user.name", "Spec")
    File.write(File.join(root, "f.txt"), "v1\n")
    git(root, "add", ".")
    git(root, "commit", "-qm", "v1")
    git(root, "push", "-qu", "origin", "main")
    root
  end

  # Advance the member's origin by one commit (via a second clone) and return
  # the new tip SHA.
  def advance_origin(name, filename: "f.txt", content: "v2\n")
    work = File.join(@tmpdir, "#{name}-upstream")
    system("git", "clone", "-q", File.join(@tmpdir, "#{name}-origin.git"), work, out: File::NULL, err: File::NULL) || raise("clone failed")
    git(work, "config", "user.email", "spec@example.test")
    git(work, "config", "user.name", "Spec")
    File.write(File.join(work, filename), content)
    git(work, "add", ".")
    git(work, "commit", "-qm", "upstream change")
    git(work, "push", "-q", "origin", "main")
    head(work)
  end

  def head(root)
    git_output(root, "rev-parse", "HEAD").strip
  end
end
