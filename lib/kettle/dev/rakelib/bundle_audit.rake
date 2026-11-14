# frozen_string_literal: true

skip_bundle_audit = %w[1 true yes on].include?(ENV.fetch("KETTLE_DEV_SKIP_BUNDLE_AUDIT", "").downcase)
# Skips only the advisory database update; bundle:audit itself still runs.
skip_audit_update = %w[1 true yes on].include?(ENV.fetch("KETTLE_DEV_SKIP_AUDIT_UPDATE", "").downcase)

# Replaces bundler-audit's `bundle:audit:update` body. The ruby-advisory-db
# lives in one directory shared by every process (e.g. parallel family
# releases), so the update is serialized with a blocking flock on a lock file
# next to the database, and a failed update is non-fatal when a usable local
# copy exists.
redefine_audit_update_task = lambda do
  require "fileutils"
  require "bundler/audit/database"
  Rake::Task["bundle:audit:update"].clear
  # rubocop:disable Rake/DuplicateTask
  desc("Updates the bundler-audit vulnerability database (serialized; see KETTLE_DEV_SKIP_AUDIT_UPDATE)")
  task("bundle:audit:update") do
    if skip_audit_update
      warn("NOTE: bundle:audit:update skipped because KETTLE_DEV_SKIP_AUDIT_UPDATE is enabled")
      next
    end
    db_path = Bundler::Audit::Database.path
    lock_path = "#{db_path.to_s.chomp("/")}.lock"
    FileUtils.mkdir_p(File.dirname(lock_path))
    ok = File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
      lock.flock(File::LOCK_EX) # blocks until other updaters finish
      system("bundler-audit", "update")
    end
    unless ok
      if Bundler::Audit::Database.exists?(db_path)
        warn("WARNING: bundle:audit:update failed; auditing with the existing local database at #{db_path}")
      else
        warn("ERROR: bundle:audit:update failed and no local advisory database exists at #{db_path}")
        exit($?&.exitstatus || 1)
      end
    end
  end
  # rubocop:enable Rake/DuplicateTask
end

define_bundle_audit_stub_tasks = lambda do |description_prefix, warning|
  desc("#{description_prefix} bundle:audit")
  task("bundle:audit") do
    warn(warning.call("bundle:audit"))
  end
  desc("#{description_prefix} bundle:audit:update")
  task("bundle:audit:update") do # rubocop:disable Rake/DuplicateTask
    warn(warning.call("bundle:audit:update"))
  end
end

if skip_bundle_audit
  define_bundle_audit_stub_tasks.call(
    "(skipped)",
    ->(task_name) { "NOTE: #{task_name} skipped because KETTLE_DEV_SKIP_BUNDLE_AUDIT is enabled" }
  )
else
  # Setup Bundle Audit
  begin
    require "bundler/audit/task"

    Bundler::Audit::Task.new
    redefine_audit_update_task.call
    Kettle::Dev.register_default("bundle:audit:update")
    Kettle::Dev.register_default("bundle:audit")
  rescue LoadError
    # simplecov:disable -- bundler-audit is an optional development dependency.
    warn("[kettle-dev][bundle_audit.rake] failed to load bundle/audit/task") if Kettle::Dev::DEBUGGING
    define_bundle_audit_stub_tasks.call(
      "(stub)",
      ->(_task_name) { "NOTE: bundler-audit isn't installed, or is disabled for #{RUBY_VERSION} in the current environment" }
    )
    # simplecov:enable
  end
end
