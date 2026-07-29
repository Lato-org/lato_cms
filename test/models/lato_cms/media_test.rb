require "test_helper"

module LatoCms
  class MediaTest < ActiveSupport::TestCase
    test "infer_media_type classifies by content type" do
      assert_equal "image", Media.infer_media_type("image/png")
      assert_equal "video", Media.infer_media_type("video/mp4")
      assert_equal "document", Media.infer_media_type("application/pdf")
      assert_equal "file", Media.infer_media_type("application/zip")
    end

    test "variant_transformation defaults to resize_to_limit" do
      assert_equal({ resize_to_limit: [800, nil] }, Media.variant_transformation({ "width" => 800 }))
    end

    test "variant_transformation supports fit and fill modes" do
      assert_equal({ resize_to_fit: [800, 600] }, Media.variant_transformation({ "width" => 800, "height" => 600, "resize" => "fit" }))
      assert_equal({ resize_to_fill: [150, 150] }, Media.variant_transformation({ "width" => 150, "height" => 150, "resize" => "fill" }))
    end

    test "variant_transformation returns nil without dimensions" do
      assert_nil Media.variant_transformation({})
    end

    test "creating a media without a file is invalid" do
      media = build_media(attach: false)
      refute media.save
      assert_includes media.errors[:file], "can't be blank"
    end

    test "name defaults to the filename and media_type is inferred on create" do
      media = build_media(filename: "example_image.png", content_type: "image/png")
      assert media.save
      assert_equal "example_image.png", media.name
      assert_equal "image", media.media_type
    end

    test "an explicit name is not overridden by the filename" do
      media = build_media(name: "Custom name")
      assert media.save
      assert_equal "Custom name", media.name
    end

    test "thumbnail_url is nil for non-image media" do
      media = build_media(filename: "example_video.mp4", content_type: "video/mp4")
      media.save!
      assert_nil media.thumbnail_url
    end

    test "usage_count reflects page_field_media rows" do
      media = build_media
      media.save!
      field = build_field
      field.replace_media!([media.id])

      assert_equal 1, media.usage_count
    end

    test "generate_video_poster! is a no-op for non-video media" do
      media = build_media
      media.save!
      media.generate_video_poster!
      refute media.poster_file.attached?
    end

    test "alt_text is stored per locale and does not leak across locales" do
      media = build_media
      media.save!

      media.alt_text_en = "A dog running"
      media.alt_text_it = "Un cane che corre"
      media.save!
      media.reload

      assert_equal "A dog running", media.alt_text(:en)
      assert_equal "Un cane che corre", media.alt_text(:it)
      assert_nil media.alt_text(:fr)
    end

    test "alt_text without an explicit locale defaults to I18n.locale" do
      media = build_media
      media.save!

      I18n.with_locale(:it) { media.alt_text = "Un cane che corre" }

      assert_equal "Un cane che corre", media.alt_text(:it)
      assert_nil media.alt_text(:en)
    end

    test "generate_video_poster! degrades gracefully when preview unavailable" do
      media = build_media(filename: "example_video.mp4", content_type: "video/mp4")
      media.save!
      media.file.define_singleton_method(:previewable?) { false }

      assert_nothing_raised { media.generate_video_poster! }
      refute media.poster_file.attached?
    end

    test "generate_alt_text! is a no-op when no LLM is configured" do
      with_llm_unconfigured do
        media = build_media
        media.save!

        media.generate_alt_text!

        assert_empty media.alt_text_translations
      end
    end

    test "generate_alt_text! is a no-op for non-image media" do
      with_llm_configured do
        media = build_media(filename: "example_video.mp4", content_type: "video/mp4")
        media.save!
        called = false
        media.define_singleton_method(:request_alt_text_completion) { |_locales| called = true; "{}" }

        media.generate_alt_text!

        refute called
        assert_empty media.alt_text_translations
      end
    end

    test "generate_alt_text! merges the per-locale translations returned by the LLM" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_alt_text_completion) do |_locales|
          { en: "A cat on a windowsill", it: "Un gatto sul davanzale" }.to_json
        end

        media.generate_alt_text!
        media.reload

        assert_equal "A cat on a windowsill", media.alt_text(:en)
        assert_equal "Un gatto sul davanzale", media.alt_text(:it)
      end
    end

    test "generate_alt_text! ignores malformed LLM output without raising" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_alt_text_completion) { |_locales| "not json" }

        assert_nothing_raised { media.generate_alt_text! }
        assert_empty media.alt_text_translations
      end
    end

    test "generate_alt_text! degrades gracefully when the LLM request fails" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_alt_text_completion) { |_locales| raise "boom" }

        assert_nothing_raised { media.generate_alt_text! }
        assert_empty media.alt_text_translations
      end
    end

    test "generate_alt_text! re-raises when raise_on_error is true, for the Operation-driven manual regenerate" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_alt_text_completion) { |_locales| raise "boom" }

        assert_raises(RuntimeError) { media.generate_alt_text!(raise_on_error: true) }
      end
    end

    private

    def build_media(name: nil, filename: "example_image.png", content_type: "image/png", attach: true)
      media = Media.new(name: name, lato_spaces_group_id: group.id)
      media.file.attach(io: file_fixture(filename).open, filename: filename, content_type: content_type) if attach
      media
    end

    def group
      @group ||= LatoSpaces::Group.create!(name: "Media test group")
    end

    def with_llm_configured
      config = LatoCms.config
      original = [config.llm_api_url, config.llm_model, config.llm_api_key]
      config.llm_api_url = "https://api.example.com/v1"
      config.llm_model = "gpt-4o-mini"
      config.llm_api_key = "sk-test"
      yield
    ensure
      config.llm_api_url, config.llm_model, config.llm_api_key = original
    end

    # Explicitly clears LLM config for the duration of the block, rather than
    # assuming it's already unconfigured: the host app's own initializer may
    # set real credentials (e.g. for manual/local testing), which would
    # otherwise make "not configured" tests flaky and fire real API calls.
    def with_llm_unconfigured
      config = LatoCms.config
      original = [config.llm_api_url, config.llm_model, config.llm_api_key]
      config.llm_api_url = config.llm_model = config.llm_api_key = nil
      yield
    ensure
      config.llm_api_url, config.llm_model, config.llm_api_key = original
    end

    def build_field
      page = Page.create!(title: "Media test page", locale: "en", template_id: "homepage", lato_spaces_group_id: group.id)
      page.fields.create!(
        template_id: "homepage",
        template_component_id: "all_fields",
        component_id: "all_fields_example",
        field_id: "example_image"
      )
    end
  end
end
