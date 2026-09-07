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

    test "title is stored per locale like alt_text and exposed in as_json" do
      media = build_media
      media.save!

      media.title_en = "Dog on the beach"
      media.title_it = "Cane in spiaggia"
      media.save!
      media.reload

      assert_equal "Dog on the beach", media.title(:en)
      assert_equal "Cane in spiaggia", media.title(:it)
      assert_nil media.title(:fr)
      assert_equal({ "en" => "Dog on the beach", "it" => "Cane in spiaggia" }, media.as_json[:title_translations])
    end

    test "usage_urls lists the frontend URLs of the pages using the media, without duplicates or blank URLs" do
      media = build_media
      media.save!
      build_field.replace_media!([media.id])
      with_url = build_field(frontend_url: "https://example.com/about")
      with_url.replace_media!([media.id])
      # Same media on two fields of the same page must yield the URL once.
      with_url.page.fields.create!(template_id: "homepage", template_component_id: "all_fields", component_id: "all_fields_example", field_id: "example_gallery")
        .replace_media!([media.id])

      assert_equal ["https://example.com/about"], media.usage_urls
    end

    test "llm_prompt substitutes {languages} and {urls} and appends the JSON response contract" do
      with_llm_configured do
        media = build_media
        media.save!
        build_field(frontend_url: "https://example.com/about").replace_media!([media.id])
        languages = LatoCms.config.locales.join(", ")

        prompt = media.llm_prompt(:alt_text)

        assert_includes prompt, "languages: #{languages}"
        assert_includes prompt, "https://example.com/about"
        assert_includes prompt, "exactly these keys: #{languages}"
        refute_includes prompt, "{languages}"
        refute_includes prompt, "{urls}"
      end
    end

    test "llm_prompt uses the custom prompt from config when set, with 'none' as urls for unused media" do
      with_llm_configured(llm_title_prompt: "Title it in {languages}; shown at {urls}") do
        media = build_media
        media.save!

        assert_includes media.llm_prompt(:title), "Title it in #{LatoCms.config.locales.join(', ')}; shown at none"
      end
    end

    test "generate_text! is a no-op when no LLM is configured" do
      with_llm_unconfigured do
        media = build_media
        media.save!

        media.generate_text!(:alt_text)

        assert_empty media.alt_text_translations
      end
    end

    test "generate_text! is a no-op for non-image media" do
      with_llm_configured do
        media = build_media(filename: "example_video.mp4", content_type: "video/mp4")
        media.save!
        called = false
        media.define_singleton_method(:request_completion) { |_prompt| called = true; "{}" }

        media.generate_text!(:alt_text)

        refute called
        assert_empty media.alt_text_translations
      end
    end

    test "generate_text! is a no-op for an attribute switched off in config" do
      with_llm_configured(llm_generate_title: false) do
        media = build_media
        media.save!
        called = false
        media.define_singleton_method(:request_completion) { |_prompt| called = true; "{}" }

        media.generate_text!(:title)

        refute called
        assert_empty media.title_translations
      end
    end

    test "generate_text! rejects unknown attributes" do
      assert_raises(ArgumentError) { build_media.generate_text!(:name) }
    end

    test "generate_text! merges the per-locale translations returned by the LLM, per attribute" do
      with_llm_configured do
        media = build_media
        media.save!
        media.alt_text_fr = "Un chat"
        media.save!
        media.define_singleton_method(:request_completion) do |prompt|
          if prompt.include?("alt text")
            { en: "A cat on a windowsill", it: "Un gatto sul davanzale" }.to_json
          else
            { en: "Cat", it: "Gatto" }.to_json
          end
        end

        media.generate_text!(:alt_text)
        media.generate_text!(:title)
        media.reload

        assert_equal "A cat on a windowsill", media.alt_text(:en)
        assert_equal "Un gatto sul davanzale", media.alt_text(:it)
        assert_equal "Un chat", media.alt_text(:fr), "locales the LLM didn't return are kept"
        assert_equal "Cat", media.title(:en)
        assert_equal "Gatto", media.title(:it)
      end
    end

    test "generate_text! ignores malformed LLM output without raising" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_completion) { |_prompt| "not json" }

        assert_nothing_raised { media.generate_text!(:alt_text) }
        assert_empty media.alt_text_translations
      end
    end

    test "generate_text! degrades gracefully when the LLM request fails" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_completion) { |_prompt| raise "boom" }

        assert_nothing_raised { media.generate_text!(:alt_text) }
        assert_empty media.alt_text_translations
      end
    end

    test "generate_text! re-raises when raise_on_error is true, for the Operation-driven manual regenerate" do
      with_llm_configured do
        media = build_media
        media.save!
        media.define_singleton_method(:request_completion) { |_prompt| raise "boom" }

        assert_raises(RuntimeError) { media.generate_text!(:alt_text, raise_on_error: true) }
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

    # Configures a fake LLM for the block, optionally overriding any other
    # llm_* setting (e.g. `llm_generate_title: false`), restoring everything
    # afterwards.
    def with_llm_configured(**overrides)
      config = LatoCms.config
      settings = { llm_api_url: "https://api.example.com/v1", llm_model: "gpt-4o-mini", llm_api_key: "sk-test" }.merge(overrides)
      original = settings.keys.index_with { |key| config.public_send(key) }
      settings.each { |key, value| config.public_send("#{key}=", value) }
      yield
    ensure
      original&.each { |key, value| config.public_send("#{key}=", value) }
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

    def build_field(frontend_url: nil)
      page = Page.create!(title: "Media test page", locale: "en", template_id: "homepage", frontend_url: frontend_url, lato_spaces_group_id: group.id)
      page.fields.create!(
        template_id: "homepage",
        template_component_id: "all_fields",
        component_id: "all_fields_example",
        field_id: "example_image"
      )
    end
  end
end
