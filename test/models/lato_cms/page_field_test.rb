require "test_helper"

module LatoCms
  class PageFieldTest < ActiveSupport::TestCase
    # Maps a size config to the matching Active Storage variant transformation.

    test "variant_transformation defaults to resize_to_limit" do
      field = PageField.new
      assert_equal({ resize_to_limit: [800, nil] }, field.send(:variant_transformation, { "width" => 800 }))
    end

    test "variant_transformation supports fit mode" do
      field = PageField.new
      assert_equal({ resize_to_fit: [800, 600] }, field.send(:variant_transformation, { "width" => 800, "height" => 600, "resize" => "fit" }))
    end

    test "variant_transformation supports fill mode" do
      field = PageField.new
      assert_equal({ resize_to_fill: [150, 150] }, field.send(:variant_transformation, { "width" => 150, "height" => 150, "resize" => "fill" }))
    end

    test "variant_transformation returns nil without dimensions" do
      field = PageField.new
      assert_nil field.send(:variant_transformation, {})
    end

    test "attachment_variant_urls returns empty hash when no sizes configured" do
      # No component context, so field_settings is empty and no variants are produced.
      field = PageField.new
      assert_equal({}, field.send(:attachment_variant_urls, Object.new))
    end

    # ── Video field ──────────────────────────────────────────────────────────

    test "video_attachment and poster_attachment discriminate by content type" do
      field = build_video_field
      attach_video(field)
      attach_poster(field)

      assert_equal "video/mp4", field.video_attachment.content_type
      assert_equal "image/jpeg", field.poster_attachment.content_type
    end

    test "as_json for video without poster exposes url and nil poster_url" do
      field = build_video_field
      attach_video(field)

      json = field.as_json
      assert_equal "video", json[:field_type]
      assert_nil json[:value]
      assert_equal 1, json[:attachments].size

      attachment = json[:attachments].first
      assert_equal "example_video.mp4", attachment[:filename]
      assert_equal "video/mp4", attachment[:content_type]
      assert_match %r{/rails/active_storage/blobs/}, attachment[:url]
      assert attachment.key?(:poster_url)
      assert_nil attachment[:poster_url]
    end

    test "as_json for video with poster exposes both urls" do
      field = build_video_field
      attach_video(field)
      attach_poster(field)

      attachment = field.as_json[:attachments].first
      # The serialized attachment is always the video, never the poster.
      assert_equal "video/mp4", attachment[:content_type]
      assert_match %r{/rails/active_storage/blobs/}, attachment[:poster_url]
      refute_equal attachment[:url], attachment[:poster_url]
    end

    test "as_json for video without attachment returns empty attachments" do
      field = build_video_field
      assert_equal [], field.as_json[:attachments]
    end

    test "generate_video_poster! is a no-op without video" do
      field = build_video_field
      field.generate_video_poster!
      assert_equal 0, field.files.count
    end

    test "generate_video_poster! skips when poster already exists" do
      field = build_video_field
      attach_video(field)
      attach_poster(field)

      field.generate_video_poster!
      assert_equal 2, field.files.count
    end

    test "generate_video_poster! degrades gracefully when preview unavailable" do
      field = build_video_field
      attach_video(field)

      video = field.video_attachment
      # Force the "no previewer available" path regardless of local ffmpeg.
      video.define_singleton_method(:previewable?) { false }
      field.define_singleton_method(:video_attachment) { video }
      field.generate_video_poster!

      assert_equal 1, field.files.count
      assert_nil field.poster_attachment
    end

    test "generate_video_poster! never raises when preview processing fails" do
      field = build_video_field
      attach_video(field) # fake bytes: ffmpeg (when present) cannot decode them

      assert_nothing_raised { field.generate_video_poster! }
      assert_nil field.poster_attachment
    end

    private

    # Builds a persisted video field backed by the dummy app's
    # all_fields_example component, so field_config resolves type "video".
    def build_video_field
      group = LatoSpaces::Group.create!(name: "Video test group")
      page = Page.create!(title: "Video test page", locale: "en", template_id: "homepage", lato_spaces_group_id: group.id)
      page.fields.create!(
        template_id: "homepage",
        template_component_id: "all_fields",
        component_id: "all_fields_example",
        field_id: "example_video"
      )
    end

    def attach_video(field)
      field.files.attach(io: file_fixture("example_video.mp4").open, filename: "example_video.mp4", content_type: "video/mp4")
    end

    def attach_poster(field)
      field.files.attach(io: StringIO.new("fake-jpeg-bytes"), filename: "example_video_poster.jpg", content_type: "image/jpeg")
    end
  end
end
