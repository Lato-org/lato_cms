require "test_helper"

# Server-side backstop for required attachment fields: a required file/gallery
# field must end the save with at least one attachment, so the client-side
# `required` enforcement cannot be bypassed by posting directly.
class RequiredAttachmentFieldSaveTest < ActionDispatch::IntegrationTest
  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Required attachments group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Required attachments page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id) # CMS controllers require a selected spaces group
  end

  test "saving a required file field with no files returns an error" do
    # Browsers submit a blank entry for an empty file input
    save_fields(required_file: { files: [""] })

    assert_response :unprocessable_entity
    assert_field_error "required_file"
  end

  test "saving a required file field with a file succeeds" do
    save_fields(required_file: { files: [fixture_file_upload("example_image.png", "image/png")] })

    assert_response :success
    assert_equal 1, field("required_file").files.count
  end

  test "removing the last attachment of a required file field returns an error" do
    save_fields(required_file: { files: [fixture_file_upload("example_image.png", "image/png")] })
    attachment_id = field("required_file").files.first.id

    save_fields(required_file: { remove_file_ids: [attachment_id.to_s] })

    assert_response :unprocessable_entity
    assert_field_error "required_file"
  end

  test "saving a required gallery field with no files returns an error" do
    # Browsers submit a blank entry for an empty file input
    save_fields(required_gallery: { files: [""] })

    assert_response :unprocessable_entity
    assert_field_error "required_gallery"
  end

  test "saving a required gallery field with images succeeds" do
    save_fields(required_gallery: { files: [fixture_file_upload("example_image.png", "image/png")] })

    assert_response :success
    assert_equal 1, field("required_gallery").files.count
  end

  test "removing the last image of a required gallery field returns an error" do
    save_fields(required_gallery: { files: [fixture_file_upload("example_image.png", "image/png")] })
    attachment_id = field("required_gallery").files.first.id

    save_fields(required_gallery: { remove_file_ids: [attachment_id.to_s] })

    assert_response :unprocessable_entity
    assert_field_error "required_gallery"
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

  def assert_field_error(field_id)
    error = response.parsed_body["errors"].find { |e| e["field_id"] == field_id }
    assert error, "expected an error for #{field_id}"
    assert_includes error["errors"], I18n.t("lato_cms.field_required_attachment_error")
  end
end
