require "test_helper"

# Regression guard: the field partials/helpers reference route helpers and
# model methods that unit tests (which mostly hit JSON endpoints) don't
# exercise. Rendering the actual HTML show page is the only thing that
# catches a typo'd path helper or a removed method used in a view.
class PageShowRenderTest < ActionDispatch::IntegrationTest
  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Page show render group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Show render page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)
  end

  test "renders successfully with every field type unfilled" do
    get lato_cms.pages_show_url(@page)
    assert_response :success
  end

  test "renders successfully with image/video/file/gallery fields populated" do
    media = create_media
    %w[example_image example_video example_file example_gallery].each do |field_id|
      field = @page.fields.create!(template_id: "homepage", template_component_id: "all_fields", component_id: "all_fields_example", field_id: field_id)
      field.replace_media!([media.id])
    end

    get lato_cms.pages_show_url(@page)
    assert_response :success
    assert_includes response.body, "lato-cms-media-field"
  end

  private

  def create_media
    media = LatoCms::Media.new(lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture("example_image.png").open, filename: "example_image.png", content_type: "image/png")
    media.save!
    media
  end
end
