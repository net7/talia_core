# Load the helper class
require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
  
  # Test the ActiveSource
  class CollectionTest < Test::Unit::TestCase
    
    #    fixtures :active_sources, :semantic_properties, :semantic_relations
     
    def setup
      setup_once(:flush) { TestHelper::flush_store }
    end
    
    def test_resource_type
      collection = Collection.new('http://testvalue.org/ordered_set/type')
      # check class
      assert_kind_of Collection, collection
      # check type
      #      assert_equal 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq', collection.types.to_s
    end
    
    def test_rdf_types
      collection = Collection.new('http://testvalue.org/ordered_set/types')
      collection.save!
      types = ActiveRDF::Query.new(N::URI).select(:type).where(collection, N::RDF.type, :type).execute
      assert(types.include?(N::DCNS.Collection))
      assert(types.include?(N::SKOS.Collection))
      assert(types.include?(N::DCMIT.Collection))
    end
    
    def test_elements
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set/elenments')
      collection.save!
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
      item_3 = ActiveSource.new('http://testvalue.org/item_3')
      
      # add items to Collection
      collection[(RDF::_000001).uri].add_record(item_1, 1)
      collection[(RDF::_000002).uri].add_record(item_2, 2)
      collection[(RDF::_000003).uri].add_record(item_3, 3)
      collection.save!
      
      # check if all items are inserted
      assert_equal 4, collection.size
      assert_equal item_1.uri, collection.elements[0].uri
      assert_equal item_2.uri, collection.elements[1].uri
      assert_equal item_3.uri, collection.elements[2].uri
    end
    
    def test_add
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set')
      collection.save!
      assert collection.empty?
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
       
      # add item to ordered source
      collection << item_1
      collection.save!
      
      # check if all items are inserted
      assert_equal 1, collection.size
      assert_equal item_1.uri, collection.elements[0].uri
      
      collection << item_2
      collection.save!
      
      # check if all items are inserted
      assert_equal 2, collection.size
      assert_equal item_1.uri, collection.elements[0].uri
      assert_equal item_2.uri, collection.elements[1].uri
    end
    
    def test_remove
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set_remove')
      collection.save!
      assert collection.empty?
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
       
      # add items to ordered source
      collection << item_1
      collection << item_2
      
      # check if all items are inserted
      assert_equal 2, collection.size
      assert_equal item_1.uri, collection.elements[0].uri
      assert_equal item_2.uri, collection.elements[1].uri
      
      # test delete item 0
      collection.delete_at 0
      
      # check if item1 is been deleted
      assert_equal 1, collection.size
      assert_equal item_2.uri, collection.elements[0].uri
      
      # test delete item 0
      collection.delete_at 0
      collection.save!
      
      # check if item 0 is been deleted
      assert_equal 0, collection.size
      
      # add items to ordered source
      collection << item_1
      collection << item_2
      
      # delete all item
      collection.clear
      
      # check if all items are been deleted
      assert_equal 0, collection.size
      assert collection.empty?
    end
    
        
    def test_replace
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set/replace')
      collection.save!
      assert collection.empty?
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
      item_3 = ActiveSource.new('http://testvalue.org/item_3')
       
      # add items to ordered source
      collection << item_1
      collection << item_2
      
      # check if all items are inserted
      assert_equal 2, collection.size
      assert_equal item_1.uri, collection.elements[0].uri
      assert_equal item_2.uri, collection.elements[1].uri
      
      # test delete item 0
      collection[0] = item_3
      
      # check if item1 is been replaced
      assert_equal 2, collection.size
      assert_not_equal item_1.uri, collection.elements[0].uri
      assert_equal item_3.uri, collection.elements[0].uri
      assert_equal item_2.uri, collection.elements[1].uri
    end
    
    def test_size
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set/size')
      collection.save!
      assert collection.empty?
      
      # the size must be 0
      assert_equal 0, collection.size
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
      item_3 = ActiveSource.new('http://testvalue.org/item_3')
      
      # add items to Collection
      collection[101] = item_1
      collection[103] = item_3
      collection[102] = item_2

      # the size must be 104 (counting the 0-element
      assert_equal 104, collection.size
    end
    
    def test_at
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set/at')
      collection.save!
      assert collection.empty?
      
      # the size must be 0
      assert_equal 0, collection.size
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
      item_3 = ActiveSource.new('http://testvalue.org/item_3')
      
      # add items to Collection
      collection << item_1
      collection << item_2
      collection << item_3
      
      # check at method
      assert_kind_of TaliaCore::ActiveSource, collection[0]
      assert_equal item_1.uri, collection[0].uri
      assert_kind_of TaliaCore::ActiveSource, collection[1]
      assert_equal item_2.uri, collection[1].uri
      assert_kind_of TaliaCore::ActiveSource, collection.at(2)
      assert_equal item_3.uri, collection.at(2).uri
    end
    
    def test_add_more_then_10_items
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set/tenit')
      collection.save!
      assert_equal 0, collection.size, "#{collection.collect { |el| el.uri }}"
      
      # the size must be 0
      assert_equal 0, collection.size
      
      # create 12 items
      items = []
      (1..12).each do |idx|
        items[idx] = ActiveSource.new("http://testvalue.org/item_#{idx}")
        collection << items[idx]
      end
      
      # check at method
      (1..12).each do |idx|
        assert_kind_of TaliaCore::ActiveSource, collection.at(idx - 1)
        assert_equal items[idx].uri, collection.at(idx - 1).uri
      end
      
      # test order
      elements = collection.collect { |el| el.uri }
      elements_array = []
      (1..12).each { |idx| elements_array << "http://testvalue.org/item_#{idx}" }
      assert_equal elements_array, elements
    end
    
    def test_find_collection
      # create new Collection
      collection = Collection.new('http://testvalue.org/ordered_set/find')
      collection.save!
      assert collection.empty?
      
      # the size must be 0
      assert_equal 0, collection.size
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
      item_2 = ActiveSource.new('http://testvalue.org/item_2')
      item_3 = ActiveSource.new('http://testvalue.org/item_3')
      
      # add items to Collection
      collection << item_1
      collection << item_2
      collection << item_3
      
      # test find method
      assert_equal 1, collection.index(item_2)
    end

    def test_save_reload
      ordered = Collection.new('http://collection_save_and_load')
      item_1 = ActiveSource.new('http://collection_save_and_load/item')
      ordered[15] = item_1
      assert_equal(item_1, ordered.at(15))
      ordered.save!
      reload = Collection.find(ordered.id)
      assert_equal(item_1, reload.at(15))
    end
    
    def test_has_part
      # create new Collection
      collection = Collection.new('http://testvalue.org/has_part')
      collection.save!
      assert collection.empty?
      
      # create 3 items
      item_1 = ActiveSource.new('http://testvalue.org/item_1')
       
      # add item to ordered source
      collection << item_1
      collection.save!
      
      assert_equal([item_1], ActiveRDF::Query.new(ActiveSource).select(:item).where(collection, N::DCT.hasPart, :item).execute)
    end
    
    def test_clear_collection_on_rdf
      # create new Collection
      collection = Collection.new('http://testvalue.org/has_clear_test')
      item = ActiveSource.new('http://testvalue.org/item_1')
      collection << item
      collection.save!
      assert_equal(1, collection.size)
      
      assert_not_equal([], ActiveRDF::Query.new(ActiveSource).select(:predicate).where(collection, :predicate, item).execute)
      
      collection.clear
      collection.save!
      
      assert_equal([], ActiveRDF::Query.new(ActiveSource).select(:predicate).where(collection, :predicate, item).execute)
    end
    
    def test_title
      collection = Collection.new('http://testvalue.org/test_title')
      collection.title = 'Foo! Bar!'
      assert_equal(collection.title, 'Foo! Bar!')
    end
    
    def test_create_empty
      collection = Collection.new
      collection.title = 'Foo!'
      assert_equal(collection.title, 'Foo!')
    end
    
    def test_reload
      collection = Collection.new('http://testvalue.org/relaod_testing_for_collection')
      item1 = ActiveSource.new("http://testvalue.org/new_reload_item1")
      item1.save!
      collection << item1
      collection.save!
      assert_equal(1, collection.size)
      new_collection = Collection.find(collection.id)
      item2 = ActiveSource.new("http://testvalue.org/new_reload_item2")
      item2.save!
      new_collection << item2
      new_collection.save
      collection.reload
      assert_equal(2, collection.size)
    end

  end
end
