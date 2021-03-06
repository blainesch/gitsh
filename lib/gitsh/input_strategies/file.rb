require 'gitsh/error'

module Gitsh
  module InputStrategies
    class File
      STDIN_PLACEHOLDER = '-'.freeze

      def initialize(opts)
        @env = opts[:env]
        @path = opts.fetch(:path)
      end

      def setup
        @file = open_file
      rescue Errno::ENOENT
        raise NoInputError, "#{path}: No such file or directory"
      rescue Errno::EACCES
        raise NoInputError, "#{path}: Permission denied"
      end

      def teardown
        if file
          file.close
        end
      end

      def read_command
        file.readline
      rescue EOFError
        nil
      end

      private

      attr_reader :env, :file, :path

      def open_file
        if path == STDIN_PLACEHOLDER
          env.input_stream
        else
          ::File.open(path)
        end
      end
    end
  end
end
