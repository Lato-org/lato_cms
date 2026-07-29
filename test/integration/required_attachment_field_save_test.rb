require "test_helper"

# Server-side backstop for required attachment fields: a required file/gallery
# field must end the save with at least one Media reference, so the
# client-side `required` enforcement cannot be bypassed by posting directly.
class RequiredAttachmentFieldSaveTest < ActionDispatch::IntegrationTest
  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Required attachments group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Required attachments page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id) # CMS controllers require a selected spaces group
  end

  test "saving a required file field with no media returns an error" do
    save_fields(required_file: { media_ids: [""] })

    assert_response :unprocessable_entity
    assert_field_error "required_file"
  end

  test "saving a required file field with a media id succeeds" do
    save_fields(required_file: { media_ids: [create_media.id] })

    assert_response :success
    assert_equal 1, field("required_file").media.count
  end

  test "removing the last media of a required file field returns an error" do
    save_fields(required_file: { media_ids: [create_media.id] })

    save_fields(required_file: { media_ids: [""] })

    assert_response :unprocessable_entity
    assert_field_error "required_file"
  end

  test "saving a required gallery field with no media returns an error" do
    save_fields(required_gallery: { media_ids: [""] })

    assert_response :unprocessable_entity
    assert_field_error "required_gallery"
  end

  test "saving a required gallery field with images succeeds" do
    save_fields(required_gallery: { media_ids: [create_media.id] })

    assert_response :success
    assert_equal 1, field("required_gallery").media.count
  end

  test "removing the last image of a required gallery field returns an error" do
    save_fields(required_gallery: { media_ids: [create_media.id] })

    save_fields(required_gallery: { media_ids: [""] })

    assert_response :unprocessable_entity
    assert_field_error "required_gallery"
  end

  test "a media id from another spaces group is silently dropped" do
    other_group = LatoSpaces::Group.create!(name: "Other group")
    foreign_media = create_media(group: other_group)

    save_fields(required_file: { media_ids: [foreign_media.id] })

    assert_response :unprocessable_entity
    assert_field_error "required_file"
  end

  private

  def save_fields(fields)
    post lato_cms.pages_save_fields_action_url(@page),
      params: {
        template_component_id: "required_attachments",
        component_id: "required_attachments_example",
        fields: fields
      },
      headers: { "Accept" => "application/json" }
  end

  def field(field_id)
    @page.fields.find_by(field_id: field_id)
  end

  def create_media(group: @group)
    media = LatoCms::Media.new(lato_spaces_group_id: group.id)
    media.file.attach(io: file_fixture("example_image.png").open, filename: "example_image.png", content_type: "image/png")
    media.save!
    media
  end

  def assert_field_error(field_id)
    error = response.parsed_body["errors"].find { |e| e["field_id"] == field_id }
    assert error, "expected an error for #{field_id}"
    assert_includes error["errors"], I18n.t("lato_cms.field_required_attachment_error")
  end
end
