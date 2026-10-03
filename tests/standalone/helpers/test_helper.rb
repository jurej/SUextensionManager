require 'minitest/mock'
require "minitest/reporters"
require 'set'

# Kludge: minitest-reporter depend on the `ansi` gem which hasn't been updated
# for a very long time. It's expecting to use another `win32console` gem in
# order to provide colorized output on Windows even though that is not longer
# needed. This works around that by fooling Ruby to think it has been loaded.
#
# https://github.com/rubyworks/ansi/issues/36
# https://github.com/rubyworks/ansi/pull/35
$LOADED_FEATURES << 'Win32/Console/ANSI'
Minitest::Reporters.use!

# Make it easier to verify the absence of a call to a mock.
class Minitest::Mock

  # @param [Symbol] name
  def refuse(name)
    @refused_calls ||= Set.new
    @refused_calls << name
    expect(name, nil) do
      raise MockExpectationError, "unexpected call to #{name}"
    end
    self
  end

  alias __verify_internal verify
  private :__verify_internal

  def verify
    @refused_calls ||= Set.new
    @refused_calls.each { |name|
      @expected_calls.delete(name)
    }
    __verify_internal
  end

end


# Define the nested extension namespace.
module TT
  module Plugins
    module ExtensionSources
    end
  end
end

# Mock UI module for testing outside SketchUp.
module UI
  def self.start_timer(interval, repeat = false, &block)
    # Return a mock timer ID
    Object.new
  end

  def self.stop_timer(timer_id)
    # No-op in test environment
  end
end

# Mock Sketchup module for testing outside SketchUp.
module Sketchup
  # Records the paths passed to `Sketchup.require` so tests can assert on
  # them via `Sketchup.required_files`.
  def self.require(path)
    required_files << path
    !failed_required_files.include?(path)
  end

  # @return [Array<String>]
  def self.required_files
    @required_files ||= []
  end

  # Paths added here will make `Sketchup.require` fail for them.
  #
  # @return [Array<String>]
  def self.failed_required_files
    @failed_required_files ||= []
  end

  # @return [Array]
  def self.extensions
    []
  end
end
