require 'test/unit'

# Load the helper class
require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')

module TaliaCore

  # Test the DataRecord storage class
  class MimeMappingTest < ActiveSupport::TestCase
    
    def setup
      @image_mime_types = ['image/gif', 'image/jpeg', 'image/png', 'image/tiff', 'image/bmp']
    end
    
    def test_class_type_from
      ['text/plain'].each do |mime|
        assert_equal(DataTypes::SimpleText, DataTypes::MimeMapping.class_type_from(mime))
      end

      @image_mime_types.each { |mime| assert_equal(DataTypes::ImageData, DataTypes::MimeMapping.class_type_from(mime), "Wrong type for #{mime} - #{DataTypes::MimeMapping.class_type_from(mime)}") }
      
      ['text/xml', 'application/xml'].each do |mime|
        assert_equal(DataTypes::XmlData, DataTypes::MimeMapping.class_type_from(mime), "Wrong type for #{mime} - #{DataTypes::MimeMapping.class_type_from(mime)}")
      end
      
      assert_equal(DataTypes::FileRecord, DataTypes::MimeMapping.class_type_from('application/rtf'))
    end
    
    def test_add_mime_mapping
      DataTypes::MimeMapping.add_mapping(Mime::Type.new('foo'), DataTypes::ImageData)
      assert_equal(DataTypes::ImageData, DataTypes::MimeMapping.class_type_from('foo'))
    end
    
    def test_add_mime_loader
      DataTypes::MimeMapping.add_mapping(Mime::Type.new('bar'), DataTypes::ImageData, :create_iip)
      assert_equal(DataTypes::ImageData, DataTypes::MimeMapping.class_type_from(:bar))
      assert_equal(:create_iip, DataTypes::MimeMapping.loader_type_from(:bar))
    end
    
  end
end