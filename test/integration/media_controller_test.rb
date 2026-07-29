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

  test "update_action edits name and per-locale alt_text but not the file" do
    media = create_media

    patch lato_cms.media_update_action_url(media),
      params: { media: { name: "New name", alt_text_en: "New alt", alt_text_it: "Nuovo alt" } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    media.reload
    assert_equal "New name", media.name
    assert_equal "New alt", media.alt_text(:en)
    assert_equal "Nuovo alt", media.alt_text(:it)
  end

  test "regenerate_alt_text_action is unavailable without an LLM configured" do
    with_llm_unconfigured do
      media = create_media

      post lato_cms.media_regenerate_alt_text_action_url(media), headers: { "Accept" => "application/json" }

      assert_response :unprocessable_entity
    end
  end

  test "regenerate_alt_text_action is unavailable for non-image media even with an LLM configured" do
    with_llm_configured do
      media = create_media(filename: "example_video.mp4", content_type: "video/mp4")

      post lato_cms.media_regenerate_alt_text_action_url(media), headers: { "Accept" => "application/json" }

      assert_response :unprocessable_entity
    end
  end

  test "regenerate_alt_text_action starts a Lato::Operation instead of running inline" do
    with_llm_configured do
      media = create_media

      assert_difference -> { Lato::Operation.count }, 1 do
        post lato_cms.media_regenerate_alt_text_action_url(media)
      end

      operation = Lato::Operation.last
      assert_equal "LatoCms::GenerateAltTextJob", operation.active_job_name
      assert_redirected_to lato.operation_path(operation)
    end
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

  def with_llm_configured
    config = LatoCms.config
    original = [config.llm_api_url, config.llm_model, config.llm_api_key]
    config.llm_api_url = "https://api.example.com/v1"
    config.llm_model = "gpt-4o-mini"
    config.llm_api_key = "sk-test"
    yield
  ensure
    config.llm_api_url, config.llm_model, config.llm_api_key = original
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
end
