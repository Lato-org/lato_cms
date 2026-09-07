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
end

def seed_text_file(group, name, filename, content_type, body)
  media = LatoCms::Media.new(name: name, lato_spaces_group_id: group.id)
  media.file.attach(io: StringIO.new(body), filename: filename, content_type: content_type)
  media.save!
end

puts "Creating sample media..."
24.times do |index|
  # Evenly spaced hues, so every generated image is visually distinguishable.
  angle = index * (360.0 / 24)
  color = [0, 120, 240].map { |offset| (Math.sin((angle + offset) * Math::PI / 180) * 96 + 128).round }
  seed_image(group, index, color)
end

seed_text_file(group, "Sample document", "sample_document.txt", "text/plain", "Sample document seeded for the dummy app.\n")
seed_text_file(group, "Sample data", "sample_data.csv", "text/csv", "name,value\nfoo,1\nbar,2\n")
seed_text_file(group, "Sample payload", "sample_payload.json", "application/json", "{\"seeded\":true}\n")
puts "Sample media created successfully (#{LatoCms::Media.count})!"
