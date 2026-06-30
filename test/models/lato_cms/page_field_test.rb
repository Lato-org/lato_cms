require "test_helper"

module LatoCms
  class PageFieldTest < ActiveSupport::TestCase
    # Maps a size config to the matching Active Storage variant transformation.

    test "variant_transformation defaults to resize_to_limit" do
      field = PageField.new
      assert_equal({ resize_to_limit: [800, nil] }, field.send(:variant_transformation, { "width" => 800 }))
    end

    test "variant_transformation supports fit mode" do
      field = PageField.new
      assert_equal({ resize_to_fit: [800, 600] }, field.send(:variant_transformation, { "width" => 800, "height" => 600, "resize" => "fit" }))
    end

    test "variant_transformation supports fill mode" do
      field = PageField.new
      assert_equal({ resize_to_fill: [150, 150] }, field.send(:variant_transformation, { "width" => 150, "height" => 150, "resize" => "fill" }))
    end

    test "variant_transformation returns nil without dimensions" do
      field = PageField.new
      assert_nil field.send(:variant_transformation, {})
    end

    test "attachment_variant_urls returns empty hash when no sizes configured" do
      # No component context, so field_settings is empty and no variants are produced.
      field = PageField.new
      assert_equal({}, field.send(:attachment_variant_urls, Object.new))
    end
  end
end
