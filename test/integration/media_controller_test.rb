require "test_helper"

class MediaControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Media controller group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)
  end

  test "create_action uploads a file and derives name/media_type" do
    post lato_cms.media_create_action_url,
      params: { media: { file: fixture_file_upload("example_image.png", "image/png") } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    body = response.parsed_body
    assert_equal "example_image.png", body["name"]
    assert_equal "image", body["media_type"]
  end

  test "update_action edits name and alt_text but not the file" do
    media = create_media

    patch lato_cms.media_update_action_url(media),
      params: { media: { name: "New name", alt_text: "New alt" } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    media.reload
    assert_equal "New name", media.name
    assert_equal "New alt", media.alt_text
  end

  test "picker_action filters by type and search query" do
    image = create_media(name: "Sunset photo")
    video = create_media(filename: "example_video.mp4", content_type: "video/mp4", name: "Intro video")

    get lato_cms.media_picker_action_url(type: "image")
    assert_includes response.body, "Sunset photo"
    refute_includes response.body, "Intro video"

    get lato_cms.media_picker_action_url(q: "sunset")
    assert_includes response.body, "Sunset photo"
    refute_includes response.body, "Intro video"
  end

  test "destroy_action is blocked while the media is still in use" do
    media = create_media
    field = build_field
    field.replace_media!([media.id])

    delete lato_cms.media_destroy_action_url(media), headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
    assert LatoCms::Media.exists?(media.id)
  end

  test "destroy_action with force=true removes an in-use media and detaches the field" do
    media = create_media
    field = build_field
    field.replace_media!([media.id])

    delete lato_cms.media_destroy_action_url(media, force: true), headers: { "Accept" => "application/json" }

    assert_response :success
    refute LatoCms::Media.exists?(media.id)
    assert_equal [], field.media.reload.pluck(:id)
  end

  private

  def create_media(name: nil, filename: "example_image.png", content_type: "image/png")
    media = LatoCms::Media.new(name: name, lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture(filename).open, filename: filename, content_type: content_type)
    media.save!
    media
  end

  def build_field
    page = LatoCms::Page.create!(title: "Media controller page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)
    page.fields.create!(
      template_id: "homepage",
      template_component_id: "all_fields",
      component_id: "all_fields_example",
      field_id: "example_image"
    )
  end
end
