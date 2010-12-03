# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

# Load the helper class
require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')

module TaliaCore
  # Test the DataRecord storage class
  class DataLoaderTest < ActiveSupport::TestCase

    fixtures :active_sources, :data_records

    WEB_TEST_URL = 'http://net7sviluppo.com/talia_test_files/'

    def setup
      setup_once(:web_test) do
        web_test_good = false
        begin
          open(WEB_TEST_URL + 'generic_test.xml') do |io|
            io.read
          end
          web_test_good = true
        rescue
          puts "*** Cannot find: #{WEB_TEST_URL + 'generic_test.xml'}, web loading test will be disabled!"
        end
        web_test_good
      end
    end

    def test_create_from_file
      loaded = DataTypes::FileRecord.create_from_url(fixture_file('generic_test.xml'))
      assert_equal(1, loaded.size)
      assert_kind_of(DataTypes::XmlData, loaded.first)
    end

    def test_options
      loaded = DataTypes::FileRecord.create_from_url(fixture_file('generic_test.xml'), :location => 'foo.xml', :mime_type => 'application/pdf')
      assert_equal(1, loaded.size)
      assert_equal('foo.xml', loaded.first.location)
      assert_equal('application/pdf', loaded.first.mime)
    end

    def test_data_loaded
      loaded = DataTypes::FileRecord.create_from_url(fixture_file('generic_test.xml')).first
      loaded.source = active_sources(:something)
      loaded.save!
      File.open(fixture_file('generic_test.xml')) do |io|
        assert_equal(io.read, loaded.all_text)
      end
    end

    def test_create_from_web
      return unless(@web_test)
      loaded = DataTypes::FileRecord.create_from_url(WEB_TEST_URL + 'generic_test.xml')
      assert_equal(1, loaded.size)
      loaded = loaded.first
      loaded.source = active_sources(:something)
      loaded.save!
      File.open(fixture_file('generic_test.xml')) do |io|
        assert_equal(io.read, loaded.all_text)
      end
    end

    def test_create_from_image
      loaded = DataTypes::FileRecord.create_from_url(fixture_file('tiny.jpg'))
      assert_equal(2, loaded.size)
      assert_equal([DataTypes::IipData, DataTypes::ImageData], loaded.collect { |t| t.class })
      assert_equal('tiny.jpg', loaded.last.location)
    end

    def test_web_create_from_image
      return unless(@web_test)
      loaded = DataTypes::FileRecord.create_from_url(WEB_TEST_URL + 'tiny.jpg')
      assert_equal(2, loaded.size)
      assert_equal([DataTypes::IipData, DataTypes::ImageData], loaded.collect { |t| t.class })
      assert_equal('tiny.jpg', loaded.last.location)
    end
    
    def test_image_creation
      loaded = DataTypes::FileRecord.create_from_url(fixture_file('tiny.jpg')).last
      loaded.source = active_sources(:something)
      loaded.save!
      assert_equal(loaded.all_bytes, File.open(fixture_file('tiny.jpg')) { |io| io.read.unpack("C*") } )
    end
    
    def test_web_image_creation
      return unless(@web_test)
      loaded = DataTypes::FileRecord.create_from_url(WEB_TEST_URL + 'tiny.jpg').last
      loaded.source = active_sources(:something)
      loaded.save!
      assert_equal(loaded.all_bytes, File.open(fixture_file('tiny.jpg')) { |io| io.read.unpack("C*") } )
    end

    def test_create_from_image_and_convert
      loaded = DataTypes::FileRecord.create_from_url(fixture_file('tiny.gif'))
      assert_equal(2, loaded.size)
      assert_equal([DataTypes::IipData, DataTypes::ImageData], loaded.collect { |t| t.class })
      loaded.each { |element| element.source = active_sources(:something) ; element.save! }
      assert_equal('image/png', loaded.last.mime)
      assert_equal('tiny.png', loaded.last.location)
    end

    def test_web_create_from_image_and_convert
      return unless(@web_test)
      loaded = DataTypes::FileRecord.create_from_url(WEB_TEST_URL + 'tiny.gif')
      assert_equal(2, loaded.size)
      assert_equal([DataTypes::IipData, DataTypes::ImageData], loaded.collect { |t| t.class })
      loaded.each { |element| element.source = active_sources(:something) ; element.save! }
      assert_equal('image/png', loaded.last.mime)
      assert_equal('tiny.png', loaded.last.location)
    end

    def test_convert_original_method
      assert(DataTypes::FileRecord.convert_original?(Mime::Type.lookup('image/tiff')))
      assert(!DataTypes::FileRecord.convert_original?(Mime::Type.lookup('image/jpeg')))
      assert(!DataTypes::FileRecord.convert_original?(:jpeg))
    end

    private

    def fixture_file(name)
      @fixture_files = File.join(ActiveSupport::TestCase.fixture_path, name)
    end

  end
end
