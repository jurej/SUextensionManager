require 'logger'
require 'observer'

require 'tt_extension_sources/utils/execution'

module TT::Plugins::ExtensionSources
  # Monitors file system changes for extension source directories.
  # Uses polling to detect modifications to .rb files within tracked paths.
  class FileSystemMonitor

    include Observable

    # @return [Float] Interval in seconds between file system checks.
    POLL_INTERVAL = 2.0
    private_constant :POLL_INTERVAL

    # @return [String] File pattern to monitor.
    FILE_PATTERN = '**/*.rb'.freeze
    private_constant :FILE_PATTERN

    # @param [Logger] logger
    def initialize(logger: Logger.new(nil))
      @logger = logger
      @tracked_paths = {}
      @timer_id = nil
      @mutex = Mutex.new
    end

    # Start monitoring a source path for file changes.
    #
    # @param [Integer] source_id Unique identifier for the source.
    # @param [String] path Directory path to monitor.
    # @return [nil]
    def track(source_id, path)
      @mutex.synchronize do
        @logger.debug { "#{self.class.object_name} track: ##{source_id} - #{path}" }
        @tracked_paths[source_id] = {
          path: path,
          last_check: Time.now,
          last_modified: scan_modification_time(path),
          update_available: false,
        }
        start_timer if @tracked_paths.size == 1
      end
      nil
    end

    # Stop monitoring a source path.
    #
    # @param [Integer] source_id Unique identifier for the source.
    # @return [nil]
    def untrack(source_id)
      @mutex.synchronize do
        @logger.debug { "#{self.class.object_name} untrack: ##{source_id}" }
        @tracked_paths.delete(source_id)
        stop_timer if @tracked_paths.empty?
      end
      nil
    end

    # Check if an update is available for the given source.
    #
    # @param [Integer] source_id Unique identifier for the source.
    # @return [Boolean]
    def update_available?(source_id)
      @mutex.synchronize do
        data = @tracked_paths[source_id]
        return false if data.nil?

        data[:update_available]
      end
    end

    # Mark a source as reloaded, resetting the update available flag.
    #
    # @param [Integer] source_id Unique identifier for the source.
    # @return [nil]
    def mark_reloaded(source_id)
      @mutex.synchronize do
        @logger.debug { "#{self.class.object_name} mark_reloaded: ##{source_id}" }
        data = @tracked_paths[source_id]
        return if data.nil?

        data[:update_available] = false
        data[:last_modified] = scan_modification_time(data[:path])
        data[:last_check] = Time.now
      end
      nil
    end

    # Stop all monitoring.
    #
    # @return [nil]
    def shutdown
      @mutex.synchronize do
        @logger.debug { "#{self.class.object_name} shutdown" }
        stop_timer
        @tracked_paths.clear
      end
      nil
    end

    private

    # Start the polling timer.
    #
    # @return [nil]
    def start_timer
      @logger.debug { "#{self.class.object_name} start_timer" }
      return if @timer_id

      @timer_id = UI.start_timer(POLL_INTERVAL, true) do
        poll_for_changes
      end
      nil
    end

    # Stop the polling timer.
    #
    # @return [nil]
    def stop_timer
      @logger.debug { "#{self.class.object_name} stop_timer" }
      return unless @timer_id

      UI.stop_timer(@timer_id)
      @timer_id = nil
    end

    # Poll all tracked paths for changes.
    #
    # @return [nil]
    def poll_for_changes
      @mutex.synchronize do
        @tracked_paths.each do |source_id, data|
          next unless File.exist?(data[:path])

          current_modified = scan_modification_time(data[:path])
          data[:last_check] = Time.now

          if current_modified > data[:last_modified]
            @logger.info { "#{self.class.object_name} change detected: ##{source_id} - #{data[:path]}" }
            data[:last_modified] = current_modified
            data[:update_available] = true
            notify_change(source_id)
          end
        end
      end
      nil
    rescue Exception => error
      @logger.error { "#{self.class.object_name} poll error: #{error.message}" }
    end

    # Notify observers of a file change.
    #
    # @param [Integer] source_id
    # @return [nil]
    def notify_change(source_id)
      changed
      notify_observers(source_id)
      nil
    end

    # Scan a directory for the latest modification time of .rb files.
    #
    # @param [String] path Directory to scan.
    # @return [Time] Latest modification time, or epoch if no files found.
    def scan_modification_time(path)
      return Time.at(0) unless File.exist?(path)

      pattern = File.join(path, FILE_PATTERN)
      files = Dir.glob(pattern)
      return Time.at(0) if files.empty?

      files.map { |file| File.mtime(file) }.max
    end

  end # class
end # module
