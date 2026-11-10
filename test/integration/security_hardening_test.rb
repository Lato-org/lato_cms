require "test_helper"

class SecurityHardeningTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Accept" => "application/json" }.freeze

  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Security hardening group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Hardening", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)
  end

  # ── frontend_url ─────────────────────────────────────────────────────────

  test "a javascript: frontend_url is rejected on update" do
    patch lato_cms.pages_update_action_url(@page), params: { page: { frontend_url: "javascript:alert(document.domain)" } }, headers: JSON_HEADERS

    assert_response :unprocessable_entity
    assert_nil @page.reload.frontend_url
  end

  test "an http(s) frontend_url is accepted" do
    patch lato_cms.pages_update_action_url(@page), params: { page: { frontend_url: "https://example.com/page" } }, headers: JSON_HEADERS

    assert_response :success
    assert_equal "https://example.com/page", @page.reload.frontend_url
  end

  test "a legacy javascript: frontend_url never reaches the iframe, links or API" do
    @page.update_column(:frontend_url, "javascript:alert(1)")

    get lato_cms.pages_show_url(@page)
    assert_response :success
    assert_select "iframe", count: 0
    assert_select "a[href^='javascript']", count: 0

    get lato_cms.pages_url
    assert_select "a[href^='javascript']", count: 0

    get lato_cms.api_pages_show_url(@page.id, group_id: @group.id)
    assert_nil response.parsed_body["frontend_url"]
  end

  test "the preview iframe is sandboxed and titled" do
    @page.update!(frontend_url: "https://example.com")

    get lato_cms.pages_show_url(@page)
    assert_select "iframe[src='https://example.com'][sandbox][title]"
  end

  test "the page title is escaped in the page head" do
    @page.update!(title: "<img src=x onerror=alert(1)>")

    get lato_cms.pages_show_url(@page)
    assert_response :success
    assert_select "h1 img", count: 0
    assert_select "h1", text: "<img src=x onerror=alert(1)>"
  end

  # ── field types come from the template ───────────────────────────────────

  test "a forged component_id cannot turn a text field into an unsanitized one" do
    @user.update!(lato_cms_admin_role: 1)
    post lato_cms.pages_save_fields_action_url(@page), params: {
      template_component_id: "all_fields", component_id: "hero",
      fields: { example_text: '<img src=x onerror=alert(1)><b>ok</b>' }
    }, headers: JSON_HEADERS
    assert_response :success

    field = @page.fields.find_by!(template_component_id: "all_fields", field_id: "example_text")
    assert_equal "all_fields_example", field.component_id

    get lato_cms.api_pages_show_url(@page.id, group_id: @group.id)
    value = response.parsed_body.dig("fields", "all_fields", "fields", "example_text")
    assert_equal "text", value["field_type"]
    refute_includes value["value"], "onerror"
  end

  test "a legacy row with a forged component_id is still sanitized by the API" do
    field = @page.fields.create!(template_id: "homepage", template_component_id: "all_fields", component_id: "all_fields_example", field_id: "example_text")
    field.update_columns(component_id: "hero", value: '<p onclick="alert(1)">Legacy</p>')

    get lato_cms.api_pages_show_url(@page.id, group_id: @group.id)
    value = response.parsed_body.dig("fields", "all_fields", "fields", "example_text", "value")
    assert_includes value, "Legacy"
    refute_includes value, "onclick"
  end

  test "a template component outside the template is rejected" do
    assert_no_difference -> { LatoCms::PageField.count } do
      post lato_cms.pages_save_fields_action_url(@page), params: {
        template_component_id: "ghost", component_id: "nope", fields: { anything: "x" }
      }, headers: JSON_HEADERS
    end

    assert_response :unprocessable_entity
  end

  test "a field id outside the component is rejected" do
    assert_no_difference -> { LatoCms::PageField.count } do
      post lato_cms.pages_save_fields_action_url(@page), params: {
        template_component_id: "all_fields", fields: { example_string: "ok", injected: "x" }
      }, headers: JSON_HEADERS
    end

    assert_response :unprocessable_entity
  end

  test "toggling a component outside the template is rejected" do
    patch lato_cms.pages_toggle_component_action_url(@page, "ghost"), params: { enabled: "0" }, headers: JSON_HEADERS

    assert_response :unprocessable_entity
    refute @page.reload.component_states.key?("ghost")
  end

  test "an unknown template_id is rejected" do
    patch lato_cms.pages_update_action_url(@page), params: { page: { template_id: "../../etc/passwd" } }, headers: JSON_HEADERS

    assert_response :unprocessable_entity
    assert_equal "homepage", @page.reload.template_id
  end

  # ── server-side field validation ─────────────────────────────────────────

  test "invalid number, color, select and multiselect values are refused with field names" do
    post lato_cms.pages_save_fields_action_url(@page), params: {
      template_component_id: "all_fields",
      fields: {
        example_number: { value: "abc" },
        example_color: { value: "red;background:url(x)" },
        example_select: { value: "not_an_option" },
        example_multiselect: { value: ["tag_1", "evil"] }
      }
    }, headers: JSON_HEADERS

    assert_response :unprocessable_entity
    errors = response.parsed_body["errors"].index_by { |error| error["field_id"] }
    assert_equal %w[example_color example_multiselect example_number example_select], errors.keys.sort
    assert_equal "Number Field", errors["example_number"]["field_name"]
  end

  test "valid typed values are saved" do
    post lato_cms.pages_save_fields_action_url(@page), params: {
      template_component_id: "all_fields",
      fields: {
        example_number: { value: "12.5" },
        example_color: { value: "#ff0000" },
        example_select: { value: "option_2" },
        example_multiselect: { value: ["tag_1", "tag_3"] }
      }
    }, headers: JSON_HEADERS

    assert_response :success
  end

  test "a required scalar field cannot be saved blank" do
    post lato_cms.pages_save_fields_action_url(@page), params: {
      template_component_id: "hero_section", fields: { title: { value: "" } }
    }, headers: JSON_HEADERS

    assert_response :unprocessable_entity
    assert_equal "title", response.parsed_body["errors"].first["field_id"]
  end

  test "an untouched color field submits no value instead of black" do
    get lato_cms.pages_show_url(@page)

    assert_select "input[type=hidden][name='fields[example_color][value]'][value='']"
    assert_select "input[type=color][name]", count: 0
  end

  # ── rate limit on expensive operations ───────────────────────────────────

  test "expensive operations are rate limited per user" do
    over_limit = LatoCms::ApplicationController::EXPENSIVE_ACTIONS_RATE_LIMIT + 1
    Rails.cache.define_singleton_method(:increment) { |*_args, **_options| over_limit }

    assert_no_difference -> { Lato::Operation.count } do
      post lato_cms.pages_sitemap_export_action_url, headers: JSON_HEADERS
    end
    assert_response :too_many_requests
  ensure
    Rails.cache.singleton_class.remove_method(:increment)
  end

  # ── media picker search ──────────────────────────────────────────────────

  test "LIKE wildcards in the picker search are matched literally" do
    media = LatoCms::Media.new(lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture("example_image.png").open, filename: "example_image.png", content_type: "image/png")
    media.save!

    get lato_cms.media_picker_action_url(frame_id: "picker", q: "%")
    assert_response :success
    assert_select "[data-media-id='#{media.id}']", count: 0
  end

  # ── uploads ──────────────────────────────────────────────────────────────

  test "an HTML upload is refused" do
    assert_no_difference -> { LatoCms::Media.count } do
      post lato_cms.media_create_action_url,
        params: { media: { file: Rack::Test::UploadedFile.new(StringIO.new("<script>alert(1)</script>"), "text/html", original_filename: "x.html") } },
        headers: JSON_HEADERS
    end

    assert_response :unprocessable_entity
  end

  test "an upload over the size limit is refused" do
    original = LatoCms.config.media_max_file_size
    LatoCms.config.media_max_file_size = 10

    assert_no_difference -> { LatoCms::Media.count } do
      post lato_cms.media_create_action_url,
        params: { media: { file: fixture_file_upload("example_image.png", "image/png") } },
        headers: JSON_HEADERS
    end
    assert_response :unprocessable_entity
  ensure
    LatoCms.config.media_max_file_size = original
  end
end
