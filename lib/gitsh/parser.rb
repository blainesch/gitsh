require 'rltk'
require 'gitsh/arguments/string_argument'
require 'gitsh/arguments/composite_argument'
require 'gitsh/arguments/variable_argument'
require 'gitsh/arguments/subshell'
require 'gitsh/commands/factory'
require 'gitsh/commands/git_command'
require 'gitsh/commands/internal_command'
require 'gitsh/commands/shell_command'
require 'gitsh/commands/noop'

module Gitsh
  class Parser < RLTK::Parser
    COMMAND_PREFIX_MATCHER = /^([:!])?(.+)$/
    COMMAND_CLASS_BY_PREFIX = {
      nil => Gitsh::Commands::GitCommand,
      ':' => Gitsh::Commands::InternalCommand,
      '!' => Gitsh::Commands::ShellCommand,
    }.freeze

    class Environment < RLTK::Parser::Environment
      attr_reader :gitsh_env

      def initialize(gitsh_env = nil)
        @gitsh_env = gitsh_env
        super()
      end
    end

    def initialize(gitsh_env)
      @env = self.class::Environment.new(gitsh_env)
    end

    left :SEMICOLON
    left :OR
    left :AND

    production(:program) do
      clause('SPACE? commands SEMICOLON? SPACE?') { |_, c, _, _| c }
      clause('SPACE?') { |_| Commands::Noop.new }
    end

    production(:commands) do
      clause('command') { |c| c }
      clause('commands SEMICOLON commands') { |c1, _, c2| Commands::Tree::Multi.new(c1, c2) }
      clause('commands OR commands') { |c1, _, c2| Commands::Tree::Or.new(c1, c2) }
      clause('commands AND commands') { |c1, _, c2| Commands::Tree::And.new(c1, c2) }
    end

    production(:command) do
      clause('word argument_list?') do |word, args|
        prefix, command = COMMAND_PREFIX_MATCHER.match(word).values_at(1, 2)

        Commands::Factory.build(
          COMMAND_CLASS_BY_PREFIX.fetch(prefix),
          env: gitsh_env,
          command: command,
          args: (args || []),
        )
      end
    end

    production(:argument_list) do
      clause('SPACE argument') { |_, arg| [arg] }
      clause('argument_list SPACE argument') { |list, _, arg| list + [arg] }
    end

    production(:argument) do
      clause('argument_part') { |part| part }
      clause('argument_part argument') do |part, argument|
        Arguments::CompositeArgument.new([part, argument])
      end
    end

    production(:argument_part) do
      clause(:word) { |word| Arguments::StringArgument.new(word) }
      clause(:VAR) { |var| Arguments::VariableArgument.new(var) }
      clause(:subshell) do |subshell|
        Arguments::Subshell.new(subshell, interpreter_factory: Interpreter)
      end
    end

    production(:word, 'WORD+') { |words| words.inject(:+) }
    production(:subshell, 'SUBSHELL+') { |subshells| subshells.inject(:+) }

    finalize
  end
end
