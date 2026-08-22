# frozen_string_literal: true

require "open3"
require "tempfile"

# Validating generated scripts with the shell itself is the point of this
# gem's suite: a regex over the output proves nothing about whether it runs.
# So a missing shell is a real gap, not a detail to work around.
#
# Locally a contributor without zsh gets a skip and a note saying why. On CI
# the same skip would mean the checks quietly stop running, so there it is a
# failure instead: every shell the suite validates must be installed.
module ShellHelpers
  # @param shell [String] executable name, e.g. "bash"
  # @return [Boolean]
  def self.available?(shell)
    @available ||= {}
    @available[shell] = which(shell) unless @available.key?(shell)
    !@available[shell].nil?
  end

  # @return [String, nil] the resolved path, or nil when the shell is absent
  def self.which(shell)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
      candidate = File.join(dir, shell)
      return candidate if File.executable?(candidate) && !File.directory?(candidate)
    end
    nil
  end

  # Call at the top of any example that shells out. Skips locally, fails on CI.
  def requires_shell(shell)
    return if ShellHelpers.available?(shell)

    if ENV["CI"]
      raise "#{shell} is not installed. CI must validate generated scripts with " \
            "every shell this gem emits; install it in the workflow."
    end

    skip "#{shell} is not installed, so its generated script cannot be validated here"
  end

  # Parses without executing: `bash -n`, `zsh -n`.
  #
  # @return [Array(Boolean, String)] whether it parsed, and anything on stderr
  def parses?(shell, script, extension)
    Tempfile.create(["completion", extension]) do |file|
      file.write(script)
      file.flush
      _stdout, stderr, status = Open3.capture3(shell, "-n", file.path)
      [status.success?, stderr]
    end
  end
end
