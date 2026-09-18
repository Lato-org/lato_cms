require "test_helper"

# Every repeater media bug so far lived in the browser, not in the controller:
# the editor's own JS rebuilt the DOM and the next save persisted whatever it
# had written. A controller test that posts a hand-written payload can never
# catch that — it asserts the payload the browser was *supposed* to send.
#
# So this test drives the real rendered editor instead: it parses the HTML the
# page ships, replays what the Stimulus controllers do to that DOM (add an item
# from the <template>, pick a media through the picker, remove one) and then
# serializes the component form exactly like FormData would before posting it.
# Anything the browser can get wrong about which item owns which media is
# reproducible here.
class RepeaterEditorSimulationTest < ActionDispatch::IntegrationTest
  COMPONENT = "feature_cards".freeze

  def setup
    @user = lato_users(:user)
    @group = LatoSpaces::Group.create!(name: "Editor simulation group")
    LatoSpaces::Membership.create!(lato_user_id: @user.id, lato_spaces_group_id: @group.id)
    @page = LatoCms::Page.create!(title: "Editor simulation page", locale: "en", template_id: "homepage", lato_spaces_group_id: @group.id)

    authenticate_user(@user)
    post lato_spaces.setgroup_url(@group.id)
  end

  test "media picked for items added in one session stay in their own item" do
    first_video = create_media(:video)
    second_video = create_media(:video)

    form = editor_form
    first_item = add_repeater_item(form)
    second_item = add_repeater_item(form)

    fill_text(form, first_item, "title", "One")
    fill_text(form, second_item, "title", "Two")
    pick_media(form, first_item, "video", first_video)
    pick_media(form, second_item, "video", second_video)

    submit(form)

    assert_response :success
    assert_equal [ first_video.id ], item_media(first_item, "video")
    assert_equal [ second_video.id ], item_media(second_item, "video")
  end

  test "removing one item's media leaves every other item untouched" do
    videos = 3.times.map { create_media(:video) }
    images = 3.times.map { create_media(:image) }
    items = seed_items(videos, images)

    form = editor_form
    remove_media(form, items.first, "video")
    submit(form)

    assert_response :success
    assert_equal [], item_media(items[0], "video")
    assert_equal [ videos[1].id ], item_media(items[1], "video")
    assert_equal [ videos[2].id ], item_media(items[2], "video")
    # The other field of the emptied item is not collateral damage.
    assert_equal [ images[0].id ], item_media(items[0], "image")
  end

  # Saving twice in a row without reloading is the flow that used to persist the
  # damage: the first save repainted the DOM from the response, the second
  # stored whatever that repaint had written.
  test "saving twice without reloading keeps every item's media" do
    videos = 3.times.map { create_media(:video) }
    images = 3.times.map { create_media(:image) }
    items = seed_items(videos, images)

    form = editor_form
    submit(form)
    repaint(form)
    submit(form)

    assert_response :success
    items.each_with_index do |item_id, index|
      assert_equal [ videos[index].id ], item_media(item_id, "video"), "item #{index} lost its video"
      assert_equal [ images[index].id ], item_media(item_id, "image"), "item #{index} lost its image"
    end
  end

  test "an item added next to saved ones does not borrow their media" do
    videos = 2.times.map { create_media(:video) }
    images = 2.times.map { create_media(:image) }
    items = seed_items(videos, images)
    fresh_video = create_media(:video)

    form = editor_form
    new_item = add_repeater_item(form)
    fill_text(form, new_item, "title", "Three")
    pick_media(form, new_item, "video", fresh_video)
    submit(form)

    assert_response :success
    assert_equal [ fresh_video.id ], item_media(new_item, "video")
    items.each_with_index { |item_id, index| assert_equal [ videos[index].id ], item_media(item_id, "video") }
  end

  # The messiest realistic session: drop an item, add another, swap one media,
  # save, let the response repaint the DOM, save again.
  test "removing, adding and swapping in one session survives two saves" do
    videos = 3.times.map { create_media(:video) }
    images = 3.times.map { create_media(:image) }
    items = seed_items(videos, images)
    swapped = create_media(:video)
    fresh = create_media(:video)

    form = editor_form
    remove_item(form, items[1])
    pick_media(form, items[0], "video", swapped)
    added = add_repeater_item(form)
    fill_text(form, added, "title", "Added")
    pick_media(form, added, "video", fresh)

    submit(form)
    repaint(form)
    submit(form)

    assert_response :success
    assert_equal [ swapped.id ], item_media(items[0], "video")
    assert_equal [ images[0].id ], item_media(items[0], "image")
    assert_equal [ videos[2].id ], item_media(items[2], "video")
    assert_equal [ fresh.id ], item_media(added, "video")
    assert_equal [], item_media(items[1], "video") # the removed item is gone for good
    # `min: 1` makes the editor seed one empty item when the repeater is empty,
    # so it leads the order: it is part of the list, not an artefact.
    assert_equal [ *@seeded_items, items[0], items[2], added ], saved_order
  end

  # A page renders every component at once, and two components can expose the
  # same field id (a template mounting the same component twice, or two
  # components that both call their image field "background_image"). Nothing
  # about a media field may be derived from the field id alone, or picking a
  # media for one component lands it in the other as well.
  test "picking a media in one component leaves the other component alone" do
    first_image = create_media(:image)

    document = editor_document
    hero = component_form(document, "hero_section")
    secondary = component_form(document, "secondary_hero")

    fill_text(hero, nil, "title", "Hero")
    fill_text(secondary, nil, "title", "Secondary")
    pick_media(document, nil, "background_image", first_image, scope: hero)

    submit(hero)
    submit(secondary)

    assert_response :success
    assert_equal [ first_image.id ], component_media("hero_section", "background_image")
    assert_equal [], component_media("secondary_hero", "background_image")
  end

  # Each form repaints from its own save response, but that response used to
  # carry every field of the page — and a field is matched by persisted field
  # id, which repeats across components. The secondary component is saved first
  # here on purpose, so its row comes first in the response and the hero would
  # match it instead of its own.
  test "saving one component does not repaint it with another component's media" do
    hero_image = create_media(:image)
    secondary_image = create_media(:image)

    document = editor_document
    hero = component_form(document, "hero_section")
    secondary = component_form(document, "secondary_hero")
    fill_text(hero, nil, "title", "Hero")
    fill_text(secondary, nil, "title", "Secondary")
    pick_media(document, nil, "background_image", hero_image, scope: hero)
    pick_media(document, nil, "background_image", secondary_image, scope: secondary)

    submit(secondary)
    submit(hero)

    repaint(hero)
    submit(hero)

    assert_response :success
    assert_equal [ hero_image.id ], component_media("hero_section", "background_image")
    assert_equal [ secondary_image.id ], component_media("secondary_hero", "background_image")
  end

  # Emptying an optional media field removes its tiles, and every hidden input
  # lives inside a tile — so the field used to drop out of the payload
  # entirely. The controller only writes the fields it receives, so the old
  # media survived the save and the repaint put the image straight back.
  test "emptying an optional image field clears it" do
    image = create_media(:image)

    document = editor_document
    hero = component_form(document, "hero_section")
    fill_text(hero, nil, "title", "Hero")
    pick_media(document, nil, "background_image", image, scope: hero)
    submit(hero)
    assert_equal [ image.id ], component_media("hero_section", "background_image")

    hero = component_form(editor_document, "hero_section")
    fill_text(hero, nil, "title", "Hero")
    remove_media(hero, nil, "background_image")
    submit(hero)

    assert_response :success
    assert_equal [], component_media("hero_section", "background_image")
  end

  private

  # --- the editor's DOM, as the browser receives it ------------------------

  def editor_document
    get lato_cms.pages_show_url(@page)
    assert_response :success

    Nokogiri::HTML(response.body)
  end

  def component_form(document, template_component_id)
    form = document.css("form").find { |node| node.at_css("input[name='template_component_id'][value='#{template_component_id}']") }
    assert form, "the #{template_component_id} component form is missing from the editor"
    form
  end

  def editor_form
    component_form(editor_document, COMPONENT)
  end

  # --- what the Stimulus controllers do to that DOM -----------------------

  # lato_cms_repeater_controller#add: clone the <template>, swap the
  # placeholders, append. Anything the server left non-unique in that markup
  # comes along for the ride, which is the point of replaying it here.
  def add_repeater_item(form)
    template = form.at_css("template[data-lato-cms-repeater-target='template']")
    item_id = SecureRandom.uuid
    markup = template.inner_html.gsub("NEW_RECORD", item_id).gsub("NEW_INDEX", form.css("[data-repeater-item-id]").size.to_s)

    template.add_previous_sibling(markup)
    item_id
  end

  # lato_cms_media_picker_controller dispatches one event correlated by frame
  # id, and every media field matching it reacts: fields sharing a frame id all
  # receive the same media, which is exactly the bug this replays.
  # `root` is the whole document on purpose: the picker's event is dispatched on
  # `document`, so every media field on the page hears it and matches by frame
  # id — not just the ones inside the form being edited.
  def pick_media(root, item_id, field_id, media, scope: nil)
    field = media_field(scope || root, item_id, field_id)
    frame_id = field["data-lato-cms-media-field-frame-id-value"]
    listeners = (root.document || root).css("[data-lato-cms-media-field-frame-id-value='#{frame_id}']")

    listeners.each do |listener|
      grid = listener.at_css("[data-lato-cms-media-field-target='grid']")
      hidden_name = listener["data-lato-cms-media-field-hidden-name-value"]
      # Single-value fields drop what they hold before taking the new pick.
      listener.css(".lato-cms-media-field__item").each(&:remove) unless listener["data-lato-cms-media-field-multiple-value"] == "true"
      append_tile(grid, hidden_name, media.id)
    end
  end

  # lato_cms_repeater_controller#remove: the whole card goes, order input
  # included, so the server never hears about that item again.
  def remove_item(form, item_id)
    form.css("[data-repeater-item-id='#{item_id}']").each(&:remove)
  end

  # lato_cms_media_field_controller#remove drops the whole tile, hidden input
  # included.
  def remove_media(form, item_id, field_id)
    media_field(form, item_id, field_id).css(".lato-cms-media-field__item").each(&:remove)
  end

  # lato_cms_media_field_controller#afterSave: after every save each media field
  # rebuilds its tiles from the JSON response, matching its own entry by
  # persisted field id. Get that match wrong and the field silently adopts
  # another item's media — hidden input included — which the next save stores
  # for real. Replayed here because it is the only thing that rewrites the DOM
  # between two saves.
  def repaint(form)
    fields = response.parsed_body.fetch("fields", [])

    form.css("[data-lato-cms-media-field-field-id-value]").each do |element|
      # `Array#find` semantics, like the JS: the FIRST entry matching the
      # persisted field id wins — which is the whole problem when that id is not
      # unique across the response.
      field = fields.find { |candidate| candidate["persisted_field_id"] == element["data-lato-cms-media-field-field-id-value"] }
      next unless field

      grid = element.at_css("[data-lato-cms-media-field-target='grid']")
      hidden_name = element["data-lato-cms-media-field-hidden-name-value"]
      element.css(".lato-cms-media-field__item").each(&:remove)
      field["attachments"].each do |attachment|
        append_tile(grid, hidden_name, attachment["media_id"])
      end
    end
  end

  # lato_cms_media_field_controller#appendItem inserts every tile just before
  # the "add" tile, i.e. after the grid's always-present empty hidden input.
  # Position matters: that sentinel is what tells the server a single-value
  # field was emptied, and Rails keeps the LAST value for a non-array param,
  # so a tile prepended ahead of it would be silently discarded.
  def append_tile(grid, hidden_name, media_id)
    add_tile = grid.at_css("[data-lato-cms-media-field-target='addTile']")
    assert add_tile, "media field grid has no add tile"
    add_tile.add_previous_sibling(%(<div class="lato-cms-media-field__item"><input type="hidden" name="#{hidden_name}" value="#{media_id}"></div>))
  end

  # `item_id` nil addresses a plain (non-repeater) component field.
  def fill_text(form, item_id, field_id, value)
    name = item_id ? "repeater_items[#{item_id}][#{field_id}][value]" : "fields[#{field_id}][value]"
    form.at_css("input[name='#{name}']")["value"] = value
  end

  def media_field(root, item_id, field_id)
    key = item_id ? "#{item_id}.#{field_id}" : field_id
    field = root.at_css("[data-lato-cms-media-field-field-id-value='#{key}']")
    assert field, "no media field for #{key}"
    field
  end

  # --- what the browser sends ---------------------------------------------

  # FormData semantics: every named, non-disabled control that is not inside a
  # <template> (inert content the browser never submits), in document order.
  def submit(form)
    payload = {}

    form.css("input[name], select[name], textarea[name]").each do |node|
      next if node.ancestors("template").any?
      next if node["disabled"]
      next if node["type"] == "checkbox" && !node["checked"]
      next if node["type"] == "submit"

      assign_param(payload, node["name"], node["value"].to_s)
    end

    post lato_cms.pages_save_fields_action_url(@page), params: payload, headers: { "Accept" => "application/json" }
  end

  # Rack's nested-params notation, built from the raw input names so the test
  # never restates by hand what the views generate.
  def assign_param(payload, name, value)
    keys = name.scan(/[^\[\]]+|\[\]/)
    cursor = payload

    keys.each_with_index do |key, index|
      last = index == keys.size - 1

      if key == "[]"
        cursor << value if last
        next
      end

      if last
        cursor[key] = value
      else
        cursor[key] ||= keys[index + 1] == "[]" ? [] : {}
        cursor = cursor[key]
      end
    end
  end

  # --- fixtures ------------------------------------------------------------

  # Three saved items, each with its own video and image, through the same
  # simulated flow (so the starting point is itself proven correct).
  def seed_items(videos, images)
    form = editor_form
    # An empty repeater renders `min` blank items up front; they stay in the
    # list, so the tests account for them rather than pretending they aren't
    # there.
    @seeded_items = form.css("[data-lato-cms-repeater-target='item']")
      .reject { |item| item.ancestors("template").any? } # the <template>'s own NEW_RECORD card
      .map { |item| item["data-repeater-item-id"] }
    items = videos.each_index.map { add_repeater_item(form) }

    items.each_with_index do |item_id, index|
      fill_text(form, item_id, "title", "Item #{index + 1}")
      pick_media(form, item_id, "video", videos[index])
      pick_media(form, item_id, "image", images[index])
    end

    submit(form)
    assert_response :success

    items.each_with_index do |item_id, index|
      assert_equal [ videos[index].id ], item_media(item_id, "video"), "seeding item #{index} already mixed the media up"
    end

    items
  end

  def saved_order
    order = @page.fields.reload.find_by(template_component_id: COMPONENT, field_id: LatoCms::PageField::REPEATER_ORDER_FIELD_ID)
    JSON.parse(order.value)
  end

  def component_media(template_component_id, field_id)
    @page.fields.reload.find_by(template_component_id: template_component_id, field_id: field_id)&.media&.pluck(:id) || []
  end

  def item_media(item_id, field_id)
    @page.fields.reload.find_by(template_component_id: COMPONENT, field_id: "#{item_id}.#{field_id}")&.media&.pluck(:id) || []
  end

  def create_media(kind)
    filename, content_type = kind == :video ? [ "example_video.mp4", "video/mp4" ] : [ "example_image.png", "image/png" ]
    media = LatoCms::Media.new(lato_spaces_group_id: @group.id)
    media.file.attach(io: file_fixture(filename).open, filename: filename, content_type: content_type)
    media.save!
    media
  end
end
