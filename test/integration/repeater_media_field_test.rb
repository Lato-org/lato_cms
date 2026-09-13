require "test_helper"

# Each repeater item must carry its own media. The field is stored as
# "<item_id>.<field_id>", but the editor's media field used to advertise only the
# bare field id: after a save every item found the first item's entry in the
# response, repainted itself with that media — hidden input included — and the
# next save stored it for real. Both items ended up with the first image.
class RepeaterMediaFieldTest < ActionDispatch::IntegrationTest
  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Repeater media group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Repeater media page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)
  end

  test "two items keep the media each one was given" do
    first_media = create_media
    second_media = create_media

    save_items(first_media.id, second_media.id)

    assert_response :success
    assert_equal [ first_media.id ], item_field("item-one").media.pluck(:id)
    assert_equal [ second_media.id ], item_field("item-two").media.pluck(:id)
  end

  test "the save response identifies each item's field by its persisted id" do
    first_media = create_media
    second_media = create_media

    save_items(first_media.id, second_media.id)

    fields = response.parsed_body["fields"].select { |f| f["field_id"] == "image" }
    assert_equal %w[item-one.image item-two.image], fields.map { |f| f["persisted_field_id"] }.sort
  end

  test "the editor renders one media field per item, each with its own persisted id" do
    save_items(create_media.id, create_media.id)

    get lato_cms.pages_show_url(@page)

    assert_response :success
    assert_includes response.body, 'data-lato-cms-media-field-field-id-value="item-one.image"'
    assert_includes response.body, 'data-lato-cms-media-field-field-id-value="item-two.image"'
  end

  private

  def save_items(first_media_id, second_media_id)
    post lato_cms.pages_save_fields_action_url(@page),
      params: {
        template_component_id: "feature_cards",
        component_id: "feature_card",
        repeater_order: %w[item-one item-two],
        repeater_items: {
          "item-one" => { title: "One", image: { media_id: first_media_id } },
          "item-two" => { title: "Two", image: { media_id: second_media_id } }
        }
      },
      as: :json
  end

  def item_field(item_id)
    @page.fields.reload.find_by!(template_component_id: "feature_cards", field_id: "#{item_id}.image")
  end

  def create_media
    media = LatoCms::Media.new(lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture("example_image.png").open, filename: "example_image.png", content_type: "image/png")
    media.save!
    media
  end
end
