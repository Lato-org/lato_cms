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

  test "update_action edits name and per-locale alt_text/title but not the file" do
    media = create_media

    patch lato_cms.media_update_action_url(media),
      params: { media: { name: "New name", alt_text_en: "New alt", alt_text_it: "Nuovo alt", title_en: "New title" } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    media.reload
    assert_equal "New name", media.name
    assert_equal "New alt", media.alt_text(:en)
    assert_equal "Nuovo alt", media.alt_text(:it)
    assert_equal "New title", media.title(:en)
  end

  test "regenerate_text_action is unavailable without an LLM configured" do
    with_llm_unconfigured do
      media = create_media

      post lato_cms.media_regenerate_text_action_url(media, attribute: "alt_text"), headers: { "Accept" => "application/json" }

      assert_response :unprocessable_entity
    end
  end

  test "regenerate_text_action is unavailable for non-image media even with an LLM configured" do
    with_llm_configured do
      media = create_media(filename: "example_video.mp4", content_type: "video/mp4")

      post lato_cms.media_regenerate_text_action_url(media, attribute: "alt_text"), headers: { "Accept" => "application/json" }

      assert_response :unprocessable_entity
    end
  end

  test "regenerate_text_action is unavailable for an attribute switched off in config" do
    with_llm_configured(llm_generate_title: false) do
      media = create_media

      post lato_cms.media_regenerate_text_action_url(media, attribute: "title"), headers: { "Accept" => "application/json" }

      assert_response :unprocessable_entity
    end
  end

  test "regenerate_text_action starts a Lato::Operation instead of running inline" do
    with_llm_configured do
      media = create_media

      assert_difference -> { Lato::Operation.count }, 1 do
        post lato_cms.media_regenerate_text_action_url(media, attribute: "alt_text")
      end

      operation = Lato::Operation.last
      assert_equal "LatoCms::GenerateMediaTextJob", operation.active_job_name
      assert_redirected_to lato.operation_path(operation)
    end
  end

  test "update renders an alt text and a title tab set, each with its own AI regenerate button" do
    with_llm_configured do
      media = create_media

      get lato_cms.media_update_url(media)

      assert_response :success
      assert_includes response.body, "media[alt_text_en]"
      assert_includes response.body, "media[title_en]"
      assert_includes response.body, lato_cms.media_regenerate_text_action_path(media, attribute: "alt_text")
      assert_includes response.body, lato_cms.media_regenerate_text_action_path(media, attribute: "title")
    end
  end

  test "index paginates 20 per page, like pages" do
    22.times { |i| create_media(name: "Paginated #{format('%02d', i + 1)}") }

    get lato_cms.media_url
    assert_response :success
    assert_equal 20, rendered_media_names.count

    get lato_cms.media_url(default_page: 2)
    assert_equal 2, rendered_media_names.count
  end

  test "update renders a large preview linking to the original file" do
    media = create_media

    get lato_cms.media_update_url(media)
    assert_response :success
    assert_includes response.body, media.preview_url
    assert_includes response.body, media.url
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

  test "show lists the pages where the media is used" do
    media = create_media
    field = build_field
    field.replace_media!([media.id])

    get lato_cms.media_show_url(media)

    assert_response :success
    assert_includes response.body, "Media controller page"
    assert_includes response.body, lato_cms.pages_show_path(field.page)
  end

  test "show reports an unused media instead of an empty list" do
    get lato_cms.media_show_url(create_media)

    assert_response :success
    assert_includes response.body, I18n.t("lato_cms.media_usages_empty")
  end

  test "show serves a video behind its poster, loading no video bytes upfront" do
    media = create_media(filename: "example_video.mp4", content_type: "video/mp4")
    media.poster_file.attach(io: file_fixture("example_image.png").open, filename: "poster.png", content_type: "image/png")

    get lato_cms.media_show_url(media)

    assert_response :success
    assert_includes response.body, %(poster="#{media.poster_url}")
    assert_includes response.body, %(preload="none")
  end

  test "update offers both the details and the replace file tab" do
    media = create_media

    get lato_cms.media_update_url(media)

    assert_response :success
    assert_includes response.body, I18n.t("lato_cms.media_update_tab_details")
    assert_includes response.body, lato_cms.media_replace_file_action_path(media)
  end

  # The Spaces association joins lato_spaces_groups, which also has a `name`
  # column: the generic index search builds unqualified SQL, so searching the
  # media library raised "ambiguous column name: name".
  test "index search matches name, alt text and title" do
    hit = create_media(name: "Sunset over the sea")
    other = create_media(name: "Mountain road")
    hit.update!(alt_text_en: "A beach at dusk")

    get lato_cms.media_url(default_search: "sunset")
    assert_response :success
    assert_includes response.body, hit.name
    refute_includes response.body, other.name

    get lato_cms.media_url(default_search: "dusk")
    assert_response :success
    assert_includes response.body, hit.name
    refute_includes response.body, other.name
  end

  test "index filters out used media when asked for unused ones" do
    used = create_media(name: "Used media")
    unused = create_media(name: "Unused media")
    build_field.replace_media!([used.id])

    get lato_cms.media_url(usage: "unused")

    assert_response :success
    assert_includes response.body, unused.name
    refute_includes response.body, used.name
  end

  test "index lists images missing an alt text in any locale" do
    complete = create_media(name: "Fully described")
    partial = create_media(name: "Half described")
    LatoCms.config.locales.each { |locale| complete.public_send("alt_text_#{locale}=", "alt"); complete.public_send("title_#{locale}=", "title") }
    complete.save!
    partial.update!(alt_text_en: "only english")

    get lato_cms.media_url(missing: "alt_text")

    assert_response :success
    assert_includes response.body, partial.name
    refute_includes response.body, complete.name
  end

  test "index lists media missing a title, images or not" do
    document = create_media(name: "Untitled doc", filename: "example_video.mp4", content_type: "video/mp4")
    titled = create_media(name: "Titled image")
    LatoCms.config.locales.each { |locale| titled.public_send("title_#{locale}=", "title") }
    titled.save!

    get lato_cms.media_url(missing: "title")

    assert_response :success
    assert_includes response.body, document.name
    refute_includes response.body, titled.name
  end

  test "index renders the delete action inert for a media still in use" do
    media = create_media(name: "Busy media")
    build_field.replace_media!([media.id])

    get lato_cms.media_url

    assert_response :success
    # The destroy path is the show path with another verb, so the marker of a
    # live delete button is the turbo method, not the href.
    refute_includes response.body, 'data-turbo-method="DELETE"'
    assert_includes response.body, I18n.t("lato_cms.media_delete_in_use", count: 1)
  end

  test "replace_file_action swaps the file keeping the same record and its usages" do
    media = create_media
    field = build_field
    field.replace_media!([media.id])
    original_blob_id = media.file.blob.id

    patch lato_cms.media_replace_file_action_url(media),
      params: { media: { file: fixture_file_upload("example_video.mp4", "video/mp4") } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    media.reload
    refute_equal original_blob_id, media.file.blob.id
    assert_equal "example_video.mp4", media.filename
    assert_equal "video", media.media_type
    assert_equal [media.id], field.media.reload.pluck(:id)
  end

  test "replace_file_action without a file is rejected" do
    media = create_media

    patch lato_cms.media_replace_file_action_url(media), headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
  end

  private

  def create_media(name: nil, filename: "example_image.png", content_type: "image/png")
    media = LatoCms::Media.new(name: name, lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture(filename).open, filename: filename, content_type: content_type)
    media.save!
    media
  end

  # Names as rendered in the index rows, to count what a page actually lists.
  def rendered_media_names
    response.body.scan(/Paginated \d{2}/).uniq
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

  # Configures a fake LLM for the block, optionally overriding any other
  # llm_* setting (e.g. `llm_generate_title: false`), restoring everything
  # afterwards.
  def with_llm_configured(**overrides)
    config = LatoCms.config
    settings = { llm_api_url: "https://api.example.com/v1", llm_model: "gpt-4o-mini", llm_api_key: "sk-test" }.merge(overrides)
    original = settings.keys.index_with { |key| config.public_send(key) }
    settings.each { |key, value| config.public_send("#{key}=", value) }
    yield
  ensure
    original&.each { |key, value| config.public_send("#{key}=", value) }
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
