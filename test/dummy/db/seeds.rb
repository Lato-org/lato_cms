require "stringio"
require "vips"

puts "Creating default admin user..."
admin = Lato::User.create!(
  first_name: "Admin",
  last_name: "Admin",
  email: "admin@mail.com",
  password: "Password1!",
  password_confirmation: "Password1!",
  accepted_privacy_policy_version: 1,
  accepted_terms_and_conditions_version: 1,
  lato_spaces_admin: true,
  lato_cms_admin_role: 2
)
puts "Default lato user created successfully!"

puts "Creating default spaces group..."
group = LatoSpaces::Group.create!(name: "Demo")
LatoSpaces::Membership.create!(lato_user_id: admin.id, lato_spaces_group_id: group.id)
puts "Default spaces group created successfully!"

# Media are generated on the fly with libvips (already a runtime dependency for
# variants) rather than shipping binary fixtures in the repo. Enough images to
# exercise pagination, plus a few non-image types so the type badges/icons and
# the picker filters have something to show.
def seed_image(group, index, color)
  width, height = [[1600, 900], [1200, 1200], [900, 1400]][index % 3]
  image = Vips::Image.black(width, height).new_from_image(color).copy(interpretation: :srgb)
  filename = "sample_#{format('%02d', index + 1)}.png"

  media = LatoCms::Media.new(name: "Sample image #{format('%02d', index + 1)}", lato_spaces_group_id: group.id)
  media.file.attach(io: StringIO.new(image.write_to_buffer(".png")), filename: filename, content_type: "image/png")
  media.save!
  media
end

def seed_text_file(group, name, filename, content_type, body)
  media = LatoCms::Media.new(name: name, lato_spaces_group_id: group.id)
  media.file.attach(io: StringIO.new(body), filename: filename, content_type: content_type)
  media.save!
  media
end

# Videos come from the test fixture (the repo already carries it): generating
# one would mean shelling out to ffmpeg, which is optional here. Poster
# generation is enqueued as usual, so it only produces a poster when ffmpeg is
# actually installed — which is the difference the video fields are meant to
# show.
def seed_video(group, index)
  media = LatoCms::Media.new(name: "Sample video #{format('%02d', index + 1)}", lato_spaces_group_id: group.id)
  media.file.attach(
    io: LatoCms::Engine.root.join("test/fixtures/files/example_video.mp4").open,
    filename: "sample_video_#{format('%02d', index + 1)}.mp4",
    content_type: "video/mp4"
  )
  media.save!
  media
end

puts "Creating sample media..."
images = 24.times.map do |index|
  # Evenly spaced hues, so every generated image is visually distinguishable.
  angle = index * (360.0 / 24)
  color = [0, 120, 240].map { |offset| (Math.sin((angle + offset) * Math::PI / 180) * 96 + 128).round }
  seed_image(group, index, color)
end

videos = 4.times.map { |index| seed_video(group, index) }

seed_text_file(group, "Sample document", "sample_document.txt", "text/plain", "Sample document seeded for the dummy app.\n")
seed_text_file(group, "Sample data", "sample_data.csv", "text/csv", "name,value\nfoo,1\nbar,2\n")
seed_text_file(group, "Sample payload", "sample_payload.json", "application/json", "{\"seeded\":true}\n")

# Left deliberately without an alt text and a title in some locales, so the
# library's "missing alt text" / "missing title" filters have something to list.
images.first.update!(alt_text_en: "A flat colour sample image", title_en: "Sample image")
images.second.update!(title_en: "Only titled in English")
puts "Sample media created successfully (#{LatoCms::Media.count})!"

# ── Pages ────────────────────────────────────────────────────────────────────
# A page per locale, linked as translations, with every component of the
# `homepage` template filled in — including the `feature_cards` repeater, whose
# items each carry their own image and video. That repeater is where media
# ownership bugs show up, so it is seeded with enough items (and enough
# distinct media) to see one item borrow another's file at a glance.

def seed_field(page, template_component_id, component_id, field_id, value: nil, media: [])
  field = page.fields.build(
    template_id: page.template_id,
    template_component_id: template_component_id,
    component_id: component_id,
    field_id: field_id,
    value: value
  )

  # Same two-step dance the controller does: a required attachment field can
  # only pass validation once the media are attached, and they need the field's
  # id to be attached at all.
  field.save(validate: false)
  field.replace_media!(Array(media).map(&:id)) if media.present?
  field.save!
  field
end

def seed_repeater(page, items)
  item_ids = items.size.times.map { SecureRandom.uuid }

  seed_field(page, "feature_cards", "feature_card", LatoCms::PageField::REPEATER_ORDER_FIELD_ID, value: item_ids.to_json)

  items.each_with_index do |item, index|
    item_id = item_ids[index]
    seed_field(page, "feature_cards", "feature_card", "#{item_id}.title", value: item[:title])
    seed_field(page, "feature_cards", "feature_card", "#{item_id}.description", value: item[:description])
    seed_field(page, "feature_cards", "feature_card", "#{item_id}.icon", value: item[:icon])
    seed_field(page, "feature_cards", "feature_card", "#{item_id}.image", media: item[:image])
    seed_field(page, "feature_cards", "feature_card", "#{item_id}.video", media: item[:video])
  end
end

def seed_page(group, locale:, title:, permalink:, images:, videos:, cards:)
  page = LatoCms::Page.create!(
    title: title,
    locale: locale,
    permalink: permalink,
    template_id: "homepage",
    frontend_url: "https://example.com#{permalink}",
    lato_spaces_group_id: group.id
  )

  seed_field(page, "hero_section", "hero", "title", value: title)
  seed_field(page, "hero_section", "hero", "subtitle", value: "Seeded #{locale.upcase} page for the dummy app.")
  seed_field(page, "hero_section", "hero", "background_image", media: images[0])

  seed_field(page, "all_fields", "all_fields_example", "example_string", value: "A string value")
  seed_field(page, "all_fields", "all_fields_example", "example_textarea", value: "Some longer text\non two lines.")
  seed_field(page, "all_fields", "all_fields_example", "example_text", value: "<p>Rich <strong>text</strong> content.</p>")
  seed_field(page, "all_fields", "all_fields_example", "example_number", value: "42")
  seed_field(page, "all_fields", "all_fields_example", "example_boolean", value: "true")
  seed_field(page, "all_fields", "all_fields_example", "example_select", value: "option_2")
  seed_field(page, "all_fields", "all_fields_example", "example_image", media: images[1])
  seed_field(page, "all_fields", "all_fields_example", "example_video", media: videos[0])
  seed_field(page, "all_fields", "all_fields_example", "example_gallery", media: images[2..4])

  seed_field(page, "required_attachments", "required_attachments_example", "required_file", media: images[5..6])
  seed_field(page, "required_attachments", "required_attachments_example", "required_gallery", media: images[7..8])

  seed_repeater(page, cards)
  page
end

puts "Creating sample pages..."
en_cards = [
  { title: "First card", description: "The first repeater item.", icon: "bi-1-circle", image: images[9], video: videos[1] },
  { title: "Second card", description: "The second repeater item.", icon: "bi-2-circle", image: images[10], video: videos[2] },
  { title: "Third card", description: "The third repeater item.", icon: "bi-3-circle", image: images[11], video: videos[3] }
]
it_cards = [
  { title: "Prima card", description: "Il primo elemento del ripetitore.", icon: "bi-1-circle", image: images[12], video: videos[3] },
  { title: "Seconda card", description: "Il secondo elemento del ripetitore.", icon: "bi-2-circle", image: images[13], video: videos[2] }
]

english = seed_page(group, locale: "en", title: "Homepage", permalink: "/", images: images, videos: videos, cards: en_cards)
italian = seed_page(group, locale: "it", title: "Home", permalink: "/it", images: images.rotate(6), videos: videos.rotate(1), cards: it_cards)
english.link_translation(italian)

# A page with no fields at all: the empty state of the editor, and a permalink
# without a frontend URL so the "no preview" state is reachable too.
LatoCms::Page.create!(title: "Empty page", locale: "en", permalink: "/empty", template_id: "homepage", lato_spaces_group_id: group.id)

puts "Sample pages created successfully (#{LatoCms::Page.count})!"
