# Load the helper class
require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')

module TaliaCore
  # Test the DataRecord storage class
  class DataRecordTest < ActiveSupport::TestCase

    fixtures :active_sources, :data_records

    def setup
      @test_records = DataTypes::DataRecord.find_data_records(Fixtures.identify(:something))

      @image_mime_types = ['image/gif', 'image/jpeg', 'image/png', 'image/tiff', 'image/bmp']
    end

    # test not nil and records numbers
    def test_records_numbers
      assert_not_equal [], @test_records
      assert_equal 15, @test_records.size
    end

    # test class type and mime_type
    def test_mime_types
      assert_kind_of(DataTypes::SimpleText, @test_records[0])
      assert_kind_of(DataTypes::SimpleText, @test_records[1])
      assert_equal("text/plain", @test_records[0].mime_type)
      assert_equal("text/plain", @test_records[1].mime_type)
    end



    # test for specific classes methods
    def test_specific_classes_methods
      # Get a line
      line = "LINE1: This is a simple text to check the DataRecords class\n"
      assert_equal(line, @test_records[0].get_line)
    end

  end  
end
