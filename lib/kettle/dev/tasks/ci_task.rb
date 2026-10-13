# frozen_string_literal: true

# External
require "open3"
require "net/http"
require "json"
require "uri"
require "io/console"

module Kettle
  module Dev
    module Tasks
      module CITask
        module_function

        # Local abort indirection to enable mocking via ExitAdapter
        def task_abort(msg)
          raise Kettle::Dev::Error, msg
        end

        # Runs `act` for a selected workflow. Option can be a short code or workflow basename.
        # @param opt [String, nil]
        def act(opt = nil)
          choice = opt&.strip

          root_dir = Kettle::Dev::CIHelpers.project_root
          workflows_dir = File.join(root_dir, ".github", "workflows")

          # Build mapping dynamically from workflow files; short code = first three letters of filename stem
          mapping = {}

          existing_files = if Dir.exist?(workflows_dir)
            Dir[File.join(workflows_dir, "*.yml")] + Dir[File.join(workflows_dir, "*.yaml")]
          else
            []
          end
          existing_basenames = existing_files.map { |p| File.basename(p) }

          exclusions = Kettle::Dev::CIHelpers.exclusions
          candidate_files = existing_basenames.uniq - exclusions
          candidate_files.sort.each do |fname|
            stem = fname.sub(/\.(ya?ml)\z/, "")
            code = stem[0, 3].to_s.downcase
            next if code.empty?
            mapping[code] ||= fname
          end

          dynamic_files = candidate_files - mapping.values
          display_code_for = {}
          mapping.keys.each { |k| display_code_for[k] = k }
          dynamic_files.each { |f| display_code_for[f] = "" }

          status_emoji = proc do |status, conclusion|
            Kettle::Dev::CIMonitor.status_emoji(status, conclusion)
          end

          fetch_and_print_status = proc do |workflow_file|
            branch = Kettle::Dev::CIHelpers.current_branch
            org_repo = Kettle::Dev::CIHelpers.repo_info
            unless branch && org_repo
              puts "GHA status: (skipped; missing git branch or remote)"
              next
            end
            owner, repo = org_repo
            uri = URI("https://api.github.com/repos/#{owner}/#{repo}/actions/workflows/#{workflow_file}/runs?branch=#{URI.encode_www_form_component(branch)}&per_page=1")
            req = Net::HTTP::Get.new(uri)
            req["User-Agent"] = "ci:act rake task"
            token = Kettle::Dev::CIHelpers.default_token
            req["Authorization"] = "token #{token}" if token && !token.empty?
            begin
              # Share the machine-wide GitHub API budget with release monitors.
              Kettle::Dev::CIHelpers.github_rate_limit_wait!
              res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
              if res.is_a?(Net::HTTPSuccess)
                data = JSON.parse(res.body)
                run = data["workflow_runs"]&.first
                if run
                  status = run["status"]
                  conclusion = run["conclusion"]
                  emoji = status_emoji.call(status, conclusion)
                  details = [status, conclusion].compact.join("/")
                  puts "Latest GHA (#{branch}) for #{workflow_file}: #{emoji} (#{details})"
                else
                  puts "Latest GHA (#{branch}) for #{workflow_file}: none"
                end
              else
                puts "GHA status: request failed (#{res.code})"
              end
            rescue => e
              puts "GHA status: error #{e.class}: #{e.message}"
            end
          end

          # Print GitLab pipeline status (if configured) for the current branch.
          print_gitlab_status = proc do
            begin
              branch = Kettle::Dev::CIHelpers.current_branch
              # Detect any GitLab remote (not just origin), mirroring CIMonitor behavior
              gl_remotes = Kettle::Dev::CIMonitor.gitlab_remote_candidates
              if gl_remotes.nil? || gl_remotes.empty? || branch.nil?
                puts "Latest GL (#{branch || "n/a"}) pipeline: n/a"
                next
              end

              # Parse owner/repo from the first GitLab remote URL
              gl_url = Kettle::Dev::CIMonitor.remote_url(gl_remotes.first)
              owner = repo = nil
              if gl_url =~ %r{git@gitlab.com:(.+?)/(.+?)(\.git)?$}
                owner = Regexp.last_match(1)
                repo = Regexp.last_match(2).sub(/\.git\z/, "")
              elsif gl_url =~ %r{https://gitlab.com/(.+?)/(.+?)(\.git)?$}
                owner = Regexp.last_match(1)
                repo = Regexp.last_match(2).sub(/\.git\z/, "")
              end

              unless owner && repo
                puts "Latest GL (#{branch}) pipeline: n/a"
                next
              end

              pipe = Kettle::Dev::CIHelpers.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
              if pipe
                st = pipe["status"].to_s
                status = if st == "success"
                  "success"
                else
                  ((st == "failed") ? "failure" : nil)
                end
                emoji = Kettle::Dev::CIMonitor.status_emoji(st, status)
                details = [st, pipe["failure_reason"]].compact.join("/")
                puts "Latest GL (#{branch}) pipeline: #{emoji} (#{details})"
              else
                puts "Latest GL (#{branch}) pipeline: none"
              end
            rescue => e
              puts "GL status: error #{e.class}: #{e.message}"
            end
          end

          run_act_for = proc do |file_path|
            ok = system("act", "-W", file_path)
            task_abort("ci:act failed: 'act' command not found or exited with failure") unless ok
          end

          if choice && !choice.empty?
            file = if mapping.key?(choice)
              mapping.fetch(choice)
            elsif !!(/\.(yml|yaml)\z/ =~ choice)
              choice
            else
              cand_yml = File.join(workflows_dir, "#{choice}.yml")
              cand_yaml = File.join(workflows_dir, "#{choice}.yaml")
              if File.file?(cand_yml)
                "#{choice}.yml"
              elsif File.file?(cand_yaml)
                "#{choice}.yaml"
              else
                "#{choice}.yml"
              end
            end
            file_path = File.join(workflows_dir, file)
            unless File.file?(file_path)
              puts "Unknown option or missing workflow file: #{choice} -> #{file}"
              puts "Available options:"
              mapping.each { |k, v| puts "  #{k.ljust(3)} => #{v}" }
              unless dynamic_files.empty?
                puts "  (others) =>"
                dynamic_files.each { |v| puts "        #{v}" }
              end
              task_abort("ci:act aborted")
            end
            fetch_and_print_status.call(file)
            print_gitlab_status.call
            run_act_for.call(file_path)
            return
          end

          # Interactive menu
          tty = $stdout.tty?
          options = mapping.to_a + dynamic_files.map { |f| [f, f] }
          quit_code = "q"
          options_with_quit = options + [[quit_code, "(quit)"]]
          idx_by_code = {}
          options_with_quit.each_with_index { |(k, _v), i| idx_by_code[k] = i }

          branch = Kettle::Dev::CIHelpers.current_branch
          org = Kettle::Dev::CIHelpers.repo_info
          owner, repo = org if org
          token = Kettle::Dev::CIHelpers.default_token

          upstream = begin
            out, status = Open3.capture2("git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
            status.success? ? out.strip : nil
          rescue => e
            Kettle::Dev.debug_error(e, __method__)
            nil
          end
          sha = begin
            out, status = Open3.capture2("git", "rev-parse", "--short", "HEAD")
            status.success? ? out.strip : nil
          rescue => e
            Kettle::Dev.debug_error(e, __method__)
            nil
          end
          if org && branch
            puts "Repo: #{owner}/#{repo}"
          elsif org
            puts "Repo: #{owner}/#{repo}"
          else
            puts "Repo: n/a"
          end
          puts "Upstream: #{upstream || "n/a"}"
          puts "HEAD: #{sha || "n/a"}"

          # Compare remote HEAD SHAs between GitHub and GitLab for current branch and highlight mismatch
          begin
            branch_name = branch
            if branch_name
              gh_remote = Kettle::Dev::CIMonitor.preferred_github_remote
              gl_remote = Kettle::Dev::CIMonitor.gitlab_remote_candidates.first
              gh_sha = nil
              gl_sha = nil
              if gh_remote
                out, status = Open3.capture2("git", "ls-remote", gh_remote.to_s, "refs/heads/#{branch_name}")
                gh_sha = out.split(/\s+/).first if status.success? && out && !out.empty?
              end
              if gl_remote
                out, status = Open3.capture2("git", "ls-remote", gl_remote.to_s, "refs/heads/#{branch_name}")
                gl_sha = out.split(/\s+/).first if status.success? && out && !out.empty?
              end
              if gh_sha && gl_sha
                gh_short = gh_sha[0, 7]
                gl_short = gl_sha[0, 7]
                if gh_short != gl_short
                  puts "⚠️ HEAD mismatch on #{branch_name}: GitHub #{gh_short} vs GitLab #{gl_short}"
                end
              end
            end
          rescue => e
            Kettle::Dev.debug_error(e, __method__)
          end

          print_gitlab_status.call
          puts
          puts "Select a workflow to run with 'act':"

          placeholder = "[…]"
          options_with_quit.each_with_index do |(k, v), idx|
            status_col = (k == quit_code) ? "" : placeholder
            disp = (k == quit_code) ? k : display_code_for[k]
            line = format("%2d) %-3s => %-20s %s", idx + 1, disp, v, status_col)
            puts line
          end

          puts "(Fetching latest GHA status for branch #{branch || "n/a"} — you can type your choice and press Enter)"
          prompt = "Enter number or code (or 'q' to quit): "
          if tty
            print(prompt)
            $stdout.flush
          end

          # We need to sleep a bit here to ensure the terminal is ready for both
          #   input and writing status updates to each workflow's line
          sleep(0.2)

          selected = nil
          input_thread = nil
          read_input = proc do
            begin
              selected = Kettle::Dev::InputAdapter.gets&.strip
            rescue StandardError, SystemExit, Interrupt => error
              puts "Error reading input: #{error.class}: #{error.message}" if Kettle::Dev::DEBUGGING
              selected = :input_error
            end
          end
          if tty
            input_thread = Thread.new(&read_input) # rubocop:disable ThreadSafety/NewThread
          else
            read_input.call
          end

          status_q = Queue.new
          workers = []
          start_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          options.each do |code, file|
            workers << Thread.new(code, file, owner, repo, branch, token, start_at) do |c, f, ow, rp, br, tk, st_at| # rubocop:disable ThreadSafety/NewThread
              begin
                now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                delay = 0.12 - (now - st_at)
                sleep(delay) if delay && delay > 0

                if ow.nil? || rp.nil? || br.nil?
                  status_q << [c, f, "n/a"]
                  Thread.exit
                end
                uri = URI("https://api.github.com/repos/#{ow}/#{rp}/actions/workflows/#{f}/runs?branch=#{URI.encode_www_form_component(br)}&per_page=1")
                poll_interval = Integer(ENV["CI_ACT_POLL_INTERVAL"] || 5)
                loop do
                  begin
                    req = Net::HTTP::Get.new(uri)
                    req["User-Agent"] = "ci:act rake task"
                    req["Authorization"] = "token #{tk}" if tk && !tk.empty?
                    # Share the machine-wide GitHub API budget with release monitors.
                    Kettle::Dev::CIHelpers.github_rate_limit_wait!
                    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
                    if res.is_a?(Net::HTTPSuccess)
                      data = JSON.parse(res.body)
                      run = data["workflow_runs"]&.first
                      if run
                        st = run["status"]
                        con = run["conclusion"]
                        emoji = Kettle::Dev::CIMonitor.status_emoji(st, con)
                        details = [st, con].compact.join("/")
                        status_q << [c, f, "#{emoji} (#{details})"]
                        break if st == "completed"
                      else
                        status_q << [c, f, "none"]
                        break
                      end
                    else
                      status_q << [c, f, "fail #{res.code}"]
                    end
                  rescue Exception => e # rubocop:disable Lint/RescueException
                    Kettle::Dev.debug_error(e, __method__)
                    # Catch all exceptions to prevent crashing the process from a worker thread
                    status_q << [c, f, "err"]
                  end
                  sleep(poll_interval)
                end
              rescue Exception => e # rubocop:disable Lint/RescueException
                Kettle::Dev.debug_error(e, __method__)
                # simplecov:disable
                # Catch all exceptions in the worker thread boundary, including SystemExit
                status_q << [c, f, "err"]
                # simplecov:enable
              end
            end
          end

          statuses = Hash.new(placeholder)

          # In non-interactive environments (no TTY) and when not DEBUGGING, auto-quit after a short idle
          auto_quit_deadline = if !tty && !Kettle::Dev::DEBUGGING
            Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.0
          end

          loop do
            if selected
              break
            end

            # Auto-quit if deadline passed without input (non-interactive runs)
            if auto_quit_deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= auto_quit_deadline
              selected = "q"
              break
            end

            begin
              code, file_name, display = status_q.pop(true)
              statuses[code] = display

              if tty
                idx = idx_by_code[code]
                if idx.nil?
                  puts "status #{code}: #{display}"
                  print(prompt)
                else
                  move_up = options_with_quit.size - idx + 1
                  $stdout.print("\e[#{move_up}A\r\e[2K")
                  disp = (code == quit_code) ? code : display_code_for[code]
                  $stdout.print(format("%2d) %-3s => %-20s %s\n", idx + 1, disp, file_name, display))
                  $stdout.print("\e[#{move_up - 1}B\r")
                  $stdout.print(prompt)
                end
                $stdout.flush
              else
                puts "status #{code}: #{display}"
              end
            rescue ThreadError
              # ThreadError is raised when the queue is empty,
              #   and it needs to be silent to maintain the output row alignment
              sleep(0.05)
            end
          end

          begin
            workers.each { |t| t.kill if t&.alive? }
          rescue => e
            Kettle::Dev.debug_error(e, __method__)
          end
          begin
            input_thread.kill if input_thread&.alive?
          rescue => e
            Kettle::Dev.debug_error(e, __method__)
          end

          input = (selected == :input_error) ? nil : selected
          task_abort("ci:act aborted: no selection") if input.nil? || input.empty?

          chosen_file = nil
          if !!(/^\d+$/ =~ input)
            idx = input.to_i - 1
            if idx < 0 || idx >= options_with_quit.length
              task_abort("ci:act aborted: invalid selection #{input}")
            end
            code, val = options_with_quit[idx]
            if code == quit_code
              puts "ci:act: quit"
              return
            else
              chosen_file = val
            end
          else
            code = input
            if ["q", "quit", "exit"].include?(code.downcase)
              puts "ci:act: quit"
              return
            end
            chosen_file = mapping[code]
            task_abort("ci:act aborted: unknown code '#{code}'") unless chosen_file
          end

          file_path = File.join(workflows_dir, chosen_file)
          task_abort("ci:act aborted: workflow not found: #{file_path}") unless File.file?(file_path)
          fetch_and_print_status.call(chosen_file)
          run_act_for.call(file_path)
          Kettle::Dev::CIMonitor.monitor_gitlab!(restart_hint: "bundle exec rake ci:act")
        end
      end
    end
  end
end
