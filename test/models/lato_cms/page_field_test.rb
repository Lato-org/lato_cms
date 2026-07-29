require "test_helper"

module LatoCms
  class PageFieldTest < ActiveSupport::TestCase
    # ── replace_media! ───────────────────────────────────────────────────────

    test "replace_media! creates join rows in the given order" do
      field = build_field("example_gallery")
      a = create_media
      b = create_media

      field.replace_media!([b.id, a.id])

      assert_equal [b.id, a.id], field.media.pluck(:id)
      assert_equal [0, 1], field.page_field_media.order(:position).pluck(:position)
    end

    test "replace_media! removes ids no longer present and reorders the rest" do
      field = build_field("example_gallery")
      a = create_media
      b = create_media
      c = create_media
      field.replace_media!([a.id, b.id, c.id])

      field.replace_media!([c.id, a.id])

      assert_equal [c.id, a.id], field.media.reload.pluck(:id)
    end

    test "replace_media! ignores blank ids" do
      field = build_field("example_image")
      media = create_media

      field.replace_media!([media.id.to_s, "", nil])

      assert_equal [media.id], field.media.pluck(:id)
    end

    # ── as_json ──────────────────────────────────────────────────────────────

    test "as_json for image exposes a single attachment with variants" do
      field = build_field("example_image")
      media = create_media(name: "Hero image", alt_text: "A hero")
      field.replace_media!([media.id])

      attachment = field.as_json[:attachments].first
      assert_equal media.id, attachment[:media_id]
      assert_equal "Hero image", attachment[:name]
      assert_equal "A hero", attachment[:alt_text]
      assert attachment.key?(:sizes)
    end

    test "as_json for video includes poster_url" do
      field = build_field("example_video")
      media = create_media(filename: "example_video.mp4", content_type: "video/mp4")
      field.replace_media!([media.id])

      attachment = field.as_json[:attachments].first
      assert attachment.key?(:poster_url)
      assert_nil attachment[:poster_url] # poster job hasn't run in this test
    end

    test "as_json for gallery preserves join order across multiple media" do
      field = build_field("example_gallery")
      a = create_media
      b = create_media
      field.replace_media!([b.id, a.id])

      ids = field.as_json[:attachments].map { |a| a[:media_id] }
      assert_equal [b.id, a.id], ids
    end

    test "as_json without any media returns empty attachments" do
      field = build_field("example_image")
      assert_equal [], field.as_json[:attachments]
    end

    # ── required validation ─────────────────────────────────────────────────

    test "a required attachment field without media is invalid" do
      page = build_page
      field = page.fields.new(
        template_id: "homepage", template_component_id: "required_attachments",
        component_id: "required_attachments_example", field_id: "required_file"
      )

      refute field.valid?
      assert_includes field.errors[:base], I18n.t("lato_cms.field_required_attachment_error")
    end

    test "a required attachment field with media is valid" do
      page = build_page
      field = page.fields.new(
        template_id: "homepage", template_component_id: "required_attachments",
        component_id: "required_attachments_example", field_id: "required_file"
      )
      # Mirrors PagesController#save_field: a brand new required field needs an
      # id before media can be attached, so the first save skips validation.
      field.save!(validate: false)
      field.replace_media!([create_media.id])

      assert field.valid?
    end

    private

    def group
      @group ||= LatoSpaces::Group.create!(name: "Page field test group")
    end

    def build_page
      @page ||= Page.create!(title: "Page field test page", locale: "en", template_id: "homepage", lato_spaces_group_id: group.id)
    end

    def build_field(field_id)
      build_page.fields.create!(
        template_id: "homepage",
        template_component_id: "all_fields",
        component_id: "all_fields_example",
        field_id: field_id
      )
    end

    def create_media(name: nil, filename: "example_image.png", content_type: "image/png", alt_text: nil)
      media = Media.new(name: name, alt_text: alt_text, lato_spaces_group_id: group.id)
      media.file.attach(io: file_fixture(filename).open, filename: filename, content_type: content_type)
      media.save!
      media
    end
  end
end
