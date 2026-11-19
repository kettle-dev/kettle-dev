# frozen_string_literal: true

require "optparse"

module Kettle
  module Dev
    class RebaseCLI
      def initialize(argv = [], root: Kettle::Dev::CIHelpers.project_root)
        @argv = Array(argv).dup
        @root = root
      end

      def run!
        args = parse!
        target = args.first.to_s
        target = root if target.empty?
        raise Error, "unexpected argument(s): #{args.drop(1).join(" ")}" if args.length > 1

        result = Rebase.call(root: target)
        puts result.message
        result.ok? ? 0 : 1
      end

      private

      attr_reader :argv, :root

      def parse!
        parser.parse!(argv)
      rescue OptionParser::ParseError => error
        raise Error, error.message
      end

      def parser
        OptionParser.new do |opts|
          opts.banner = "Usage: kettle-rebase [PATH]"
          opts.separator "Sync PATH (default: project root) to its upstream with git pull --rebase --autostash."
          opts.separator "No-op when up to date; aborts and reports on rebase conflict."
        end
      end
    end
  end
end
