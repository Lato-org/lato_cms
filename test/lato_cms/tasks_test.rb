require "test_helper"
require "rake"

module LatoCms
  class TasksTest < ActiveSupport::TestCase
    def setup
      Rails.application.load_tasks unless Rake::Task.task_defined?("lato_cms:generate:component")
      @dir = Dir.mktmpdir
      @original_path = LatoCms.config.templates_path
      LatoCms.config.templates_path = @dir
    end

    def teardown
      LatoCms.config.templates_path = @original_path
      FileUtils.remove_entry(@dir)
      Rake::Task["lato_cms:generate:component"].reenable
      Rake::Task["lato_cms:generate:custom_field"].reenable
    end

    test "generate:component aborts on an unsupported field type instead of falling back to string" do
      assert_raises(SystemExit) do
        capture_io { Rake::Task["lato_cms:generate:component"].invoke("hero", "title:string", "cover:imagez") }
      end
      refute File.exist?(File.join(@dir, "components", "hero.yml"))
    end

    test "generate:component accepts media field types" do
      capture_io { Rake::Task["lato_cms:generate:component"].invoke("gallery_block", "cover:image", "photos:gallery") }

      fields = YAML.load_file(File.join(@dir, "components", "gallery_block.yml"))["fields"]
      assert_equal %w[image gallery], fields.values.map { |field| field["type"] }
    end
  end
end
