# frozen_string_literal: true

module MyCLI
  # Starts the CLI. The executable and the spec suite each build one, with
  # their own argv and streams, and it exits only through kernel.exit.
  #
  # @example
  #   MyCLI::Launcher.new(%w[find-hosts --port 22]).execute!
  class Launcher
    # @param argv [Array<String>] the arguments, without the program name
    # @param _stdin [IO] accepted for Aruba's in-process launcher; no command reads it
    # @param stdout [IO] where results go
    # @param stderr [IO] where errors, spinners and progress bars go
    # @param kernel [#exit] what the exit status is handed to
    def initialize(argv, _stdin = $stdin, stdout = $stdout, stderr = $stderr, kernel = Kernel)
      @argv   = argv
      @stdout = stdout
      @stderr = stderr
      @kernel = kernel
    end

    # Runs the command argv names, then exits with its status.
    #
    # @return [void]
    def execute!
      kernel.exit(run)
    end

    private

    # @return [Array<String>]
    attr_reader :argv

    # @return [IO]
    attr_reader :stdout

    # @return [IO]
    attr_reader :stderr

    # @return [#exit]
    attr_reader :kernel

    # dry-cli exits by itself after help or a usage error; its status is kept.
    #
    # @return [Integer] the exit status
    def run
      Dry::CLI.new(CLI::Commands).call(arguments: argv, out: stdout, err: stderr)
      0
    rescue SystemExit => e
      e.status
    rescue StandardError => e
      stderr.puts "error: #{e.message}"
      1
    end
  end
end
