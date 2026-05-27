require 'minitest/autorun'
require 'test_helper'

require 'tmpdir'
require 'fileutils'

require 'tt_extension_sources/system/file_system_monitor'

module TT::Plugins::ExtensionSources
  class FileSystemMonitorTest < Minitest::Test

    def setup
      @monitor = FileSystemMonitor.new
    end

    def teardown
      @monitor.shutdown
    end


    def test_track_adds_path_to_monitoring
      Dir.mktmpdir do |dir|
        source_id = 1
        @monitor.track(source_id, dir)
        refute(@monitor.update_available?(source_id))
      end
    end

    def test_untrack_removes_path_from_monitoring
      Dir.mktmpdir do |dir|
        source_id = 1
        @monitor.track(source_id, dir)
        @monitor.untrack(source_id)
        refute(@monitor.update_available?(source_id))
      end
    end

    def test_shutdown_clears_all_tracked_paths
      Dir.mktmpdir do |dir|
        source_id = 1
        @monitor.track(source_id, dir)
        @monitor.shutdown
        refute(@monitor.update_available?(source_id))
      end
    end


    def test_scan_modification_time_returns_epoch_for_nonexistent_path
      fake_path = '/fake/nonexistent/path'
      # Using send to test private method
      result = @monitor.send(:scan_modification_time, fake_path)
      assert_equal(Time.at(0), result)
    end

    def test_scan_modification_time_returns_epoch_for_empty_directory
      Dir.mktmpdir do |dir|
        result = @monitor.send(:scan_modification_time, dir)
        assert_equal(Time.at(0), result)
      end
    end

    def test_scan_modification_time_finds_latest_modified_file
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'test1.rb')
        file2 = File.join(dir, 'test2.rb')

        File.write(file1, '# test1')
        sleep(0.1)  # Ensure different modification times
        File.write(file2, '# test2')

        result = @monitor.send(:scan_modification_time, dir)
        assert_in_delta(File.mtime(file2), result, 1.0)
      end
    end

    def test_scan_modification_time_checks_subdirectories
      Dir.mktmpdir do |dir|
        subdir = File.join(dir, 'subdir')
        FileUtils.mkdir_p(subdir)

        file = File.join(subdir, 'test.rb')
        File.write(file, '# test')

        result = @monitor.send(:scan_modification_time, dir)
        assert_in_delta(File.mtime(file), result, 1.0)
      end
    end


    def test_mark_reloaded_clears_update_available
      Dir.mktmpdir do |dir|
        source_id = 1
        @monitor.track(source_id, dir)

        # Manually set update_available
        @monitor.instance_variable_get(:@tracked_paths)[source_id][:update_available] = true

        @monitor.mark_reloaded(source_id)
        refute(@monitor.update_available?(source_id))
      end
    end


    def test_update_available_returns_false_for_untracked_source
      refute(@monitor.update_available?(999))
    end


    def test_notify_change_triggers_observers
      Dir.mktmpdir do |dir|
        source_id = 1
        observer = TestObserver.new

        @monitor.add_observer(observer)
        @monitor.track(source_id, dir)
        @monitor.send(:notify_change, source_id)
        @monitor.delete_observer(observer)

        assert_equal([source_id], observer.notifications)
      end
    end

    # Simple test observer class.
    class TestObserver
      attr_reader :notifications

      def initialize
        @notifications = []
      end

      def update(source_id)
        @notifications << source_id
      end
    end

  end # class
end # module
