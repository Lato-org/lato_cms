require "test_helper"

class RichTextSecurityTest < ActionDispatch::IntegrationTest
  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Rich text security group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Security", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)
    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)
  end

  test "operator HTML cannot execute when an admin opens the editor" do
    @user.update!(lato_cms_admin_role: 1)
    post lato_cms.pages_save_fields_action_url(@page), params: {
      template_component_id: "all_fields", component_id: "all_fields_example",
      fields: { example_text: '<p onclick="alert(1)"><b>Safe content</b><img src="x" onerror="alert(1)"></p>' }
    }, headers: { "Accept" => "application/json" }
    assert_response :success

    @user.update!(lato_cms_admin_role: 2)
    get lato_cms.pages_show_url(@page)
    assert_response :success
    assert_select '[data-lato-cms-text-field-target="editor"] b', text: "Safe content"
    assert_select '[data-lato-cms-text-field-target="editor"] [onclick]', count: 0
    assert_select '[data-lato-cms-text-field-target="editor"] [onerror]', count: 0
  end

  test "opening legacy stored HTML sanitizes the editor before JavaScript runs" do
    field = @page.fields.create!(template_id: "homepage", template_component_id: "all_fields", component_id: "all_fields_example", field_id: "example_text")
    field.update_column(:value, '<p onmouseover="alert(1)">Legacy</p><script>alert(1)</script>')

    get lato_cms.pages_show_url(@page)
    assert_response :success
    assert_select '[data-lato-cms-text-field-target="editor"] p', text: "Legacy"
    assert_select '[data-lato-cms-text-field-target="editor"] [onmouseover]', count: 0
    assert_select '[data-lato-cms-text-field-target="editor"] script', count: 0
  end

  test "rich text quotes cannot escape the hidden input attribute" do
    field = @page.fields.create!(template_id: "homepage", template_component_id: "all_fields", component_id: "all_fields_example", field_id: "example_text",
      value: '<p title="Safe">Content</p>" autofocus onfocus="alert(1)')

    get lato_cms.pages_show_url(@page)
    assert_response :success
    assert_select '[data-lato-cms-text-field-target="input"]' do |inputs|
      assert_equal field.value, inputs.first["value"]
      assert_nil inputs.first["onfocus"]
      assert_nil inputs.first["autofocus"]
    end
  end
end
