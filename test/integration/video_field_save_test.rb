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

  test "uploading a video to the media library enqueues the poster job" do
    assert_enqueued_with(job: LatoCms::GenerateVideoPosterJob) do
      upload_video
    end

    assert_response :success
    media = LatoCms::Media.last
    assert_equal "video", media.media_type
  end

  test "selecting an uploaded video for the field attaches it" do
    media = upload_video_media

    save_video_field(media_id: media.id)

    assert_response :success
    field = video_field
    assert_equal [media.id], field.media.pluck(:id)

    attachment = response.parsed_body["fields"].find { |f| f["field_id"] == "example_video" }["attachments"].first
    assert_equal media.id, attachment["media_id"]
    assert attachment.key?("poster_url")
  end

  test "replacing the selected video swaps the reference without touching the old media" do
    first = upload_video_media
    second = upload_video_media
    save_video_field(media_id: first.id)

    save_video_field(media_id: second.id)

    assert_equal [second.id], video_field.media.reload.pluck(:id)
    assert LatoCms::Media.exists?(first.id) # the old Media itself is untouched, just unlinked
  end

  test "removing the video clears the field" do
    media = upload_video_media
    save_video_field(media_id: media.id)

    save_video_field(media_id: "")

    assert_equal [], video_field.media.reload.pluck(:id)
  end

  private

  def upload_video
    post lato_cms.media_create_action_url,
      params: { media: { file: fixture_file_upload("example_video.mp4", "video/mp4") } },
      headers: { "Accept" => "application/json" }
  end

  def upload_video_media
    upload_video
    LatoCms::Media.find(response.parsed_body["id"])
  end

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
