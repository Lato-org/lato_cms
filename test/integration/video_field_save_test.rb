require "test_helper"

class VideoFieldSaveTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Video save group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Video save page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id) # CMS controllers require a selected spaces group
  end

  test "uploading a video attaches it and enqueues the poster job" do
    assert_enqueued_with(job: LatoCms::GenerateVideoPosterJob) do
      save_video_field(files: [fixture_file_upload("example_video.mp4", "video/mp4")])
    end

    assert_response :success
    field = video_field
    assert_equal 1, field.files.count
    assert_equal "video/mp4", field.video_attachment.content_type

    # API payload exposes the video with its (not yet generated) poster url.
    attachment = response.parsed_body["fields"].find { |f| f["field_id"] == "example_video" }["attachments"].first
    assert_equal "example_video.mp4", attachment["filename"]
    assert attachment.key?("poster_url")
  end

  test "replacing the video purges the old video and its poster" do
    save_video_field(files: [fixture_file_upload("example_video.mp4", "video/mp4")])
    field = video_field
    # Simulate a previously generated poster: replacement must drop it too.
    field.files.attach(io: StringIO.new("fake-jpeg-bytes"), filename: "old_poster.jpg", content_type: "image/jpeg")
    old_ids = field.files.map(&:id)

    save_video_field(files: [fixture_file_upload("example_video.mp4", "video/mp4")])

    field.reload
    assert_equal 1, field.files.count
    assert_empty old_ids & field.files.map(&:id)
    assert_equal "video/mp4", field.video_attachment.content_type
  end

  test "removing the video purges video and poster" do
    save_video_field(files: [fixture_file_upload("example_video.mp4", "video/mp4")])
    field = video_field
    field.files.attach(io: StringIO.new("fake-jpeg-bytes"), filename: "old_poster.jpg", content_type: "image/jpeg")

    save_video_field(remove_file_ids: [field.video_attachment.id.to_s])

    assert_equal 0, field.reload.files.count
  end

  private

  def save_video_field(field_data)
    post lato_cms.pages_save_fields_action_url(@page),
      params: {
        template_component_id: "all_fields",
        component_id: "all_fields_example",
        fields: { example_video: field_data }
      },
      headers: { "Accept" => "application/json" }
  end

  def video_field
    @page.fields.find_by(field_id: "example_video")
  end
end
