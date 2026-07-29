require "test_helper"

class CloneComponentActionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Clone component group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)

    @source = build_page(locale: "en")
    @target = build_page(locale: "it")
    @target.link_translation(@source)
  end

  test "clones field values verbatim without translate" do
    source_field = build_field(@source, field_id: "example_string", value: "Hello")

    post lato_cms.pages_clone_component_action_url(@target, "all_fields"),
      params: { source_page_id: @source.id },
      headers: { "Accept" => "application/json" }

    assert_response :success
    assert_equal source_field.value, target_field("example_string").value
  end

  test "translate: true clones synchronously and translates via a Lato::Operation" do
    build_field(@source, field_id: "example_string", value: "Hello")
    build_field(@source, field_id: "example_textarea", value: "Hello there")
    build_field(@source, field_id: "example_select", value: "option_2")

    with_llm_configured do
      stub_llm_chat('["Ciao", "Ciao a te"]') do
        assert_difference -> { Lato::Operation.count }, 1 do
          perform_enqueued_jobs do
            post lato_cms.pages_clone_component_action_url(@target, "all_fields"),
              params: { source_page_id: @source.id, translate: true }
          end
        end
      end
    end

    operation = Lato::Operation.last
    assert_equal "LatoCms::TranslateComponentFieldsJob", operation.active_job_name
    assert_redirected_to lato.operation_path(operation)
    assert operation.completed_status?

    # The clone itself already happened synchronously, before the operation
    # even existed — translation only overwrites the free-text fields.
    assert_equal "Ciao", target_field("example_string").value
    assert_equal "Ciao a te", target_field("example_textarea").value
    assert_equal "option_2", target_field("example_select").value # untouched: not free text
  end

  test "keeps referencing the same shared Media without touching its alt text" do
    media = LatoCms::Media.new(name: "Photo", lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture("example_image.png").open, filename: "example_image.png", content_type: "image/png")
    media.save!
    media.alt_text_en = "A photo"
    media.save!
    field = build_field(@source, field_id: "example_image")
    field.replace_media!([media.id])

    with_llm_configured do
      perform_enqueued_jobs do
        post lato_cms.pages_clone_component_action_url(@target, "all_fields"),
          params: { source_page_id: @source.id, translate: true }
      end
    end

    assert_equal [media.id], target_field("example_image").media.reload.pluck(:id)
    assert_equal "A photo", media.reload.alt_text(:en)
  end

  test "the clone survives even when the translation step fails" do
    build_field(@source, field_id: "example_string", value: "Hello")

    with_llm_configured do
      stub_llm_chat_error do
        perform_enqueued_jobs do
          post lato_cms.pages_clone_component_action_url(@target, "all_fields"),
            params: { source_page_id: @source.id, translate: true }
        end
      end
    end

    assert Lato::Operation.last.failed_status?
    assert_equal "Hello", target_field("example_string").value
  end

  test "translate: true has no effect when no LLM is configured" do
    with_llm_unconfigured do
      build_field(@source, field_id: "example_string", value: "Hello")

      post lato_cms.pages_clone_component_action_url(@target, "all_fields"),
        params: { source_page_id: @source.id, translate: true },
        headers: { "Accept" => "application/json" }

      assert_response :success
      assert_equal "Hello", target_field("example_string").value
      assert_equal 0, Lato::Operation.count
    end
  end

  private

  def build_page(locale:)
    LatoCms::Page.create!(title: "Clone test #{locale}", locale: locale, template_id: "homepage", lato_spaces_group_id: @group.id)
  end

  def build_field(page, field_id:, value: nil)
    page.fields.create!(
      template_id: "homepage",
      template_component_id: "all_fields",
      component_id: "all_fields_example",
      field_id: field_id,
      value: value
    )
  end

  def target_field(field_id)
    @target.fields.reload.find_by(field_id: field_id)
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

  def stub_llm_chat(content)
    original = LatoCms::LlmClient.method(:chat)
    LatoCms::LlmClient.define_singleton_method(:chat) { |**_| content }
    yield
  ensure
    LatoCms::LlmClient.define_singleton_method(:chat, &original)
  end

  def stub_llm_chat_error
    original = LatoCms::LlmClient.method(:chat)
    LatoCms::LlmClient.define_singleton_method(:chat) { |**_| raise "boom" }
    yield
  ensure
    LatoCms::LlmClient.define_singleton_method(:chat, &original)
  end
end
