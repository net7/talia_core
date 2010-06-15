require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
  
  class DefinedAccessorTest < ActiveSource
    autofill_uri
    singular_property :siglum, N::RDFS.siglum, :dependent => :destroy
    multi_property :authors, N::RDFS.author
    singular_property :forcy_single, N::RDFS.forcy_single, :force_relation => true
    multi_property :forcy, N::RDFS.forcy, :force_relation => true, :dependent => :destroy
    manual_property :blinko
    has_rdf_type N::TALIA.foo
    
    attr_accessor :blinko
  end
  
  class DefinedAccessorSubTest < DefinedAccessorTest
    singular_property :title, N::RDFS.title
  end
  
  class DefinedAccessorSubNaked < DefinedAccessorTest
  end
  
  # Test the ActiveSource
  class ActiveSourceTest < ActiveSupport::TestCase
    fixtures :active_sources, :semantic_properties, :semantic_relations, :data_records
    
    N::Namespace.shortcut(:as_test_preds, 'http://testvalue.org/')
    
    def setup
      setup_once(:test_file) { File.join(ActiveSupport::TestCase.fixture_path, 'generic_test.xml') }
    end

    def test_has_type
      src = ActiveSource.new('http://xsource/has_type_test')
      src.types << N::HYPER.testtype
      assert(src.has_type?(N::HYPER.testtype))
    end
    
    def test_type_field
      src = SourceTypes::DummySource.new('http://xsource/has_type_test')
      assert_equal(src.type, 'TaliaCore::SourceTypes::DummySource')
    end

    def test_exists
      assert_not_nil(ActiveSource.find(:first))
    end
    
    def test_create_existing
      src = ActiveSource.new(active_sources(:testy).uri)
      assert_equal(src, active_sources(:testy))
      assert(!src.new_record?)
    end
    
    def test_create_new
      src_uri = 'http://foobarxxx.com/imallnew'
      src = ActiveSource.new(src_uri)
      assert_equal(src_uri, src.uri)
      assert(src.new_record?)
    end
    
    def test_create_vanilla
      src = ActiveSource.new
      # Somehow this gives different results for JRuby/Ruby
      assert(src.uri == nil || src.uri == '')
      assert(src.new_record?)
    end
    
    def test_accessor
      assert_equal(3, active_sources(:multirel)['http://testvalue.org/multirel'].size)
      assert_equal(1, active_sources(:multirel)['http://testvalue.org/multi_b'].size)
    end
    
    def test_delete
      del = active_sources(:deltest)
      assert_equal(2, del['http://testvalue.org/delete_test'].size)
      del["http://testvalue.org/delete_test"].remove("Delete Me!")
      del.save!
      assert_equal(1, active_sources(:deltest)["http://testvalue.org/delete_test"].size)
    end
    
    def test_delete_relation
      del = active_sources(:deltest_rel)
      assert_equal(2, del['http://testvalue.org/delete_test'].size)
      del['http://testvalue.org/delete_test'].remove(active_sources(:deltest_rel_target1))
      del.save
      assert_equal(1, active_sources(:deltest_rel)["http://testvalue.org/delete_test"].size)
    end
    
    def test_accessor_tripledup
      assert_equal(2, active_sources(:duplicator)['http://testvalue.org/dup_rel'].size)
    end
    
    def test_accessor_tripledup_delete
      dupey = active_sources(:dup_for_delete)
      dupdouble = TaliaCore::ActiveSource.find(dupey.uri)
      assert_equal(2, dupey['http://testvalue.org/dup_rel'].size)
      dupey['http://testvalue.org/dup_rel'].remove(active_sources(:testy))
      assert_equal(1, dupey['http://testvalue.org/dup_rel'].size)
      dupey.save!
      assert_equal(1, dupdouble['http://testvalue.org/dup_rel'].size)
      assert_equal(1, dupey['http://testvalue.org/dup_rel'].size)
      dupey['http://testvalue.org/dup_rel'].remove(active_sources(:testy))
      assert_equal(0, active_sources(:dup_for_delete)['http://testvalue.org/dup_rel'].size)
      dupey.save!
      assert_equal(0, active_sources(:dup_for_delete)['http://testvalue.org/dup_rel'].size)
    end
    
    def test_uri
      assert_equal("http://testy.com/testme/hard", active_sources(:testy).uri)
    end
    
    def test_to_s
      assert_equal active_sources(:testy).uri, active_sources(:testy).to_s
    end
    
    def test_create
      src = ActiveSource.new
      src.uri = "http://www.testy.org/create_test"
      src.save!
      assert_equal(1, ActiveSource.find(:all, :conditions => { :uri =>  "http://www.testy.org/create_test" } ).size)
    end
    
    def test_associate
      test_src = active_sources(:assoc_test)
      test_src["http://foo/assoc_test"] << active_sources(:assoc_test_target)
      test_src["http://bar/assoc_test_prop"] << 'Test Value'
      test_src.save!
      assert_equal(1, test_src["http://foo/assoc_test"].size)
      assert_equal(1, active_sources(:assoc_test)["http://foo/assoc_test"].size)
      assert_equal(1, active_sources(:assoc_test)["http://bar/assoc_test_prop"].size)
      active_sources(:assoc_test).save!
      assert_equal(1, active_sources(:assoc_test)["http://foo/assoc_test"].size)
      assert_equal(1, active_sources(:assoc_test)["http://bar/assoc_test_prop"].size)
      assert_equal('TaliaCore::ActiveSource', SemanticRelation.find(:first, 
          :conditions => { 
            :subject_id => test_src.id, 
            :predicate_uri => 'http://foo/assoc_test',
            :object_id => active_sources(:assoc_test_target)
          }).object_type)
    end
    
    def test_create_validate
      src = ActiveSource.new
      assert_raise(ActiveRecord::RecordInvalid) { src.save! }
    end
    
    def test_create_validate_format
      src = ActiveSource.new
      src.uri = "invalid"
      assert_raise(ActiveRecord::RecordInvalid) { src.save! }
    end
    
    def test_create_validate_unique
      src = ActiveSource.new
      src.uri = active_sources(:testy).uri
      assert_raise(ActiveRecord::RecordInvalid) { src.save! }
    end

    def test_validate_uri
      source = ActiveSource.new(:uri => N::LOCAL.to_s)
      assert !source.valid?
      
      source = ActiveSource.new(:uri => "#{N::LOCAL}#{source}")
      assert source.valid?
    end

    def test_inverse
      assert_equal(2, active_sources(:assoc_inverse_start).inverse['http://testvalue.org/inverse_test'].size)
      second_rel = active_sources(:assoc_inverse_start).inverse['http://testvalue.org/inverse_test_rel2']
      assert_equal(1, second_rel.size)
      assert_kind_of(TaliaCore::ActiveSource, second_rel[0])
      assert_equal('http://testy.com/testme/inverse_end_c', second_rel[0].uri)
    end
    
    def test_predicate_access
      assert_equal('The test value', active_sources(:testy).predicate(:as_test_preds, :the_rel1)[0])
    end
    
    def test_predicate_assign_string
      src = active_sources(:assoc_predicate_test)
      src.predicate_set(:as_test_preds, :test, "Foo")
      src.save!
      src_chng = TaliaCore::ActiveSource.find(src.id)
      assert_equal('Foo', src_chng[N::AS_TEST_PREDS.test][0])
    end
    
    def test_predicate_assign_rel
      src = active_sources(:assoc_predicate_test)
      src.predicate_set(:as_test_preds, :test_rel, src)
      src.save!
      assert_equal(src.uri, active_sources(:assoc_predicate_test)[N::AS_TEST_PREDS.test_rel][0].uri)
    end

    def test_semantic_build_success
      src = TaliaCore::ActiveSource.new('http://buildsuccesstest/source')
      src.predicate_set(:hyper, 'buildsucc', 'test')
      src['http://buildsucc'] << 'test'
      assert_equal(1, src['http://buildsucc'].size)
      assert_equal(1,  src[N::HYPER.buildsucc].size)
      src.save!
      assert_equal(1, ActiveSource.find(src.uri)['http://buildsucc'].size)
    end
    
    def test_predicate_set_uniq
      src = active_sources(:assoc_predicate_test)
      src.predicate_set_uniq(:as_test_preds, :test_uniq, "foo")
      assert_property(src.predicate(:as_test_preds, :test_uniq), "foo")
      src.predicate_set_uniq(:as_test_preds, :test_uniq, "bar")
      src.predicate_set_uniq(:as_test_preds, :test_uniq, "foo")
      src.save!
      assert_property(src.predicate(:as_test_preds, :test_uniq), "foo", "bar")
    end

    def test_predicate_replace
      src = active_sources(:assoc_predicate_test)
      src.predicate_set(:as_test_preds, :test_replace, "foo")
      src.predicate_replace(:as_test_preds, :test_replace, "bar")
      src.save!
      assert_property(src.predicate(:as_test_preds, :test_replace), "bar")
    end
    
    def test_direct_predicates
      preds = active_sources(:predicate_search_a).direct_predicates
      assert_equal(4, preds.size)
      assert(preds.include?('http://testvalue.org/pred_b'), "#{preds} does not include the expected value")
    end
    
    def test_i18n_predicates
      src = active_sources(:i18n_test)
      assert_property(src.predicate(:as_test_preds, :i18n), 'value', 'wert')
    end
    
    def test_values_with_lang
      src = active_sources(:i18n_test)
      assert_equal(src.predicate(:as_test_preds, :i18n).values_with_lang('de'), ['wert'])
      assert_equal(src.predicate(:as_test_preds, :i18n).values_with_lang('en'), ['value'])
    end
    
    def test_values_with_lang_fallback
      src = active_sources(:i18n_test)
      assert_equal(src.predicate(:as_test_preds, :i18n).values_with_lang('ar'), ['value'])
    end
    
    def test_values_with_lang_fallback_unset
      src_preds = active_sources(:testy).predicate(:as_test_preds, :the_rel1)
      assert_equal(src_preds.values_with_lang('de'), ['The test value'])
      assert_equal(src_preds.values_with_lang('en'), ['The test value'])
    end
    
    def test_property_string_values
      src = active_sources(:i18n_test)
      pred = src.predicate(:as_test_preds, :i18n).first
      assert_kind_of(PropertyString, pred)
      assert(!pred.lang.blank?)
    end
    
    def test_property_string_adding
      src = TaliaCore::ActiveSource.new('http://testy.org/do_the_property_string')
      src[N::RDF.testpred] << PropertyString.new('value', 'en', 'string')
      assert(src[N::RDF.testpred].first.lang, 'en')
      src.save!
      src_new = TaliaCore::ActiveSource.find(src.uri)
      assert_property(src_new[N::RDF.testpred], 'value')
      pred = src_new[N::RDF.testpred].first
      assert_equal(pred.lang, 'en')
      assert_equal(pred.type, 'string')
    end

    def test_predicates_prefetch
      uri = active_sources(:testy)
      src = TaliaCore::ActiveSource.find(uri, :prefetch_relations => true)
      assert_equal(true, src.instance_variable_get(:@prefetched))
      type_cache = src.instance_variable_get(:@type_cache)
      assert_equal('The test value', type_cache[N::AS_TEST_PREDS.the_rel1.to_s].first)
    end
    
    def test_prefetch_finder
      srcs = TaliaCore::ActiveSource.find(:all, :prefetch_relations => true)
      src = srcs.detect { |s| s.uri.to_s == 'http://testy.com/testme/hard'}
      assert(src)
      assert_equal(true, src.instance_variable_get(:@prefetched))
      type_cache = src.instance_variable_get(:@type_cache)
      assert(type_cache)
      assert_equal('The test value', type_cache[N::AS_TEST_PREDS.the_rel1.to_s].first)
      assert_equal('The test value', src.predicate(:as_test_preds, :the_rel1).first)
    end
    
    def test_prefetch_count
      count = TaliaCore::ActiveSource.count(:prefetch_relations => true)
      real_count = TaliaCore::ActiveSource.count
      assert_equal(count, real_count)
    end
    
    def test_inverse_predicates
      preds = active_sources(:predicate_search_b).inverse_predicates
      assert_equal(4, preds.size)
      assert(preds.include?('http://testvalue.org/pred_b'), "#{preds} does not include the expected value")
      assert_equal(0, active_sources(:predicate_search_b).direct_predicates.size)
    end
    
    def test_default_type
      src = ActiveSource.new('http://testy.com/testme/test_default_type')
      src.save!
      assert_equal(1, src.types.size)
      assert_property(src.types, src.rdf_selftype)
    end
    
    def test_types
      src = ActiveSource.new
      src.uri = 'http://testy.com/testme/type_test'
      src.save!
      src.types << N::SourceClass.new(active_sources(:type_a).uri)
      src.types << N::SourceClass.new(active_sources(:type_b).uri)
      src.save!
      assert_property(src.types, active_sources(:type_a).uri, active_sources(:type_b).uri, src.rdf_selftype)
      assert_kind_of(N::SourceClass, src.types[0])
      assert(src.types.include?(active_sources(:type_b).uri))
    end
    
    def test_sti_simple # Single table inheritance
      assert_kind_of(TaliaCore::Collection, ActiveSource.find(:first, :conditions => { :uri => active_sources(:sti_source).uri.to_s }  ))
      assert_kind_of(TaliaCore::Collection, active_sources(:sti_source))
    end
    
    def test_sti_relation_create
      src = active_sources(:sti_source_reltest)
      src['http://reltest_test'] << active_sources(:sti_source_reltest_b)
      src['http://reltest_test_b'] << active_sources(:sti_source_reltest_c)
      src.save!
      assert_equal(1, src['http://reltest_test'].size)
      assert_equal(1, src['http://reltest_test_b'].size)
      assert_equal(TaliaCore::Collection, src['http://reltest_test'][0].class)
      assert_equal(TaliaCore::ActiveSource, src['http://reltest_test_b'][0].class)
    end
    
    def test_sti_relation_inverse
      assert_equal(1, active_sources(:sti_source_b).subjects.size)
      assert_equal(TaliaCore::Collection, active_sources(:sti_source_b).subjects[0].class)
      assert_equal(TaliaCore::Collection, active_sources(:sti_source_b).inverse['http://testvalue.org/sti_test'][0].class)
      assert_equal(active_sources(:sti_source).uri, active_sources(:sti_source_b).inverse['http://testvalue.org/sti_test'][0].uri)
    end
    
    def test_attach_large_and_strange_text
      src = active_sources(:strange_attach)
      src['http://strangeattach_prop'] << "Nous présentons un commentaire de l'aphorisme 103 du Voyageur et son ombre, que Nietzsche a intitulé \" Lessing \" et où l'oeuvre de cet écrivain est jugée du du point de vue du style. On ne comprend vraiment le problème que si on inscrit l'aphorisme dans le cadre de la réception par Nietzsche, dès ses années d'études, des oeuvres de Lessing. Il résulte de notre analyse que Nietzsche définit le style de Lessing en le comparant à ce que Nietzsche lui-même appelle l'école française. À l'époque du Voyageur, le concept de sérénité (Heiterkeit) dont Montaigne est le modèle, est central pour juger un style. La question est de savoir à quelle école française Lessing a appartenu. La réponse de Nietzsche est apparemment assez ambiguë : Lessing est rapproché non seulement de Bayle, de Voltaire, de Diderot et de Montaigne, mais aussi de Marivaux, de Corneille et de Racine."
      src.save!
      assert_equal(src['http://strangeattach_prop'][0],"Nous présentons un commentaire de l'aphorisme 103 du Voyageur et son ombre, que Nietzsche a intitulé \" Lessing \" et où l'oeuvre de cet écrivain est jugée du du point de vue du style. On ne comprend vraiment le problème que si on inscrit l'aphorisme dans le cadre de la réception par Nietzsche, dès ses années d'études, des oeuvres de Lessing. Il résulte de notre analyse que Nietzsche définit le style de Lessing en le comparant à ce que Nietzsche lui-même appelle l'école française. À l'époque du Voyageur, le concept de sérénité (Heiterkeit) dont Montaigne est le modèle, est central pour juger un style. La question est de savoir à quelle école française Lessing a appartenu. La réponse de Nietzsche est apparemment assez ambiguë : Lessing est rapproché non seulement de Bayle, de Voltaire, de Diderot et de Montaigne, mais aussi de Marivaux, de Corneille et de Racine.")
    end
    
    def test_attach_large_and_strange_text_fresh
      src = ActiveSource.new('http://freshstrangeattach.xml')
      src['http://strangeattach_prop'] << "Nous présentons un commentaire de l'aphorisme 103 du Voyageur et son ombre, que Nietzsche a intitulé \" Lessing \" et où l'oeuvre de cet écrivain est jugée du du point de vue du style.\nOn ne comprend vraiment le problème que si on inscrit l'aphorisme dans le cadre de la réception par Nietzsche, dès ses années d'études, des oeuvres de Lessing. Il résulte de notre analyse que Nietzsche définit le style de Lessing en le comparant à ce que Nietzsche lui-même appelle l'école française. À l'époque du Voyageur, le concept de sérénité (Heiterkeit) dont Montaigne est le modèle, est central pour juger un style. La question est de savoir à quelle école française Lessing a appartenu. La réponse de Nietzsche est apparemment assez ambiguë : Lessing est rapproché non seulement de Bayle, de Voltaire, de Diderot et de Montaigne, mais aussi de Marivaux, de Corneille et de Racine."
      src.save!
      assert_equal(src['http://strangeattach_prop'][0],"Nous présentons un commentaire de l'aphorisme 103 du Voyageur et son ombre, que Nietzsche a intitulé \" Lessing \" et où l'oeuvre de cet écrivain est jugée du du point de vue du style.\nOn ne comprend vraiment le problème que si on inscrit l'aphorisme dans le cadre de la réception par Nietzsche, dès ses années d'études, des oeuvres de Lessing. Il résulte de notre analyse que Nietzsche définit le style de Lessing en le comparant à ce que Nietzsche lui-même appelle l'école française. À l'époque du Voyageur, le concept de sérénité (Heiterkeit) dont Montaigne est le modèle, est central pour juger un style. La question est de savoir à quelle école française Lessing a appartenu. La réponse de Nietzsche est apparemment assez ambiguë : Lessing est rapproché non seulement de Bayle, de Voltaire, de Diderot et de Montaigne, mais aussi de Marivaux, de Corneille et de Racine.")
    end
    
    def test_destroy_from_predicate
      src = active_sources(:pred_destroy_test)
      assert_equal(2, src.direct_predicates.size)
      src['http://testvalue.org/pred_destroy_a'].remove
      src.save!
      assert_equal(1, active_sources(:pred_destroy_test).direct_predicates.size)
    end
    
    def test_create_local
      src = ActiveSource.new('testlocalthing')
      assert_equal(N::LOCAL.testlocalthing, src.uri)
    end
    
    def test_create_local_strange
      src = ActiveSource.new(:uri => '504-10,E2')
      assert_equal(N::LOCAL + '504-10,E2', src.uri)
    end
    
    def test_assign_and_save
      src = ActiveSource.new('http://testassignandsave/')
      src[N::LOCAL.something] << ActiveSource.new('http://types_test/assign_and_save_a')
      src.save!
      assert(ActiveSource.exists?(src.uri))
    end
    
    def test_assign_nil_fail
      src = ActiveSource.new('http://testassignandsave_nil/')
      assert_raise(ArgumentError) { src['rdfs:something'] << nil }
    end

    def test_find_default_order
      result = ActiveSource.find(:all, :order => :default)
      assert_equal(result.size, ActiveSource.count)
    end
  
    def test_find_with_param
      first = ActiveSource.find(:first)
      param = first.to_param
      param += "-more-garbage"
      refound = ActiveSource.find(param)
      assert_equal(first, refound)
    end
    
    def test_find_through
      result = ActiveSource.find(:all, :find_through => ['http://testvalue.org/pred_find_through', active_sources(:find_through_target).uri])
      assert_equal(1, result.size)
      assert_equal(active_sources(:find_through_test), result[0])
    end
    
    def test_find_through_evil # Checks what happens if #to_s returns a random string instead of the uri
      foo = Object.new 
      class << foo
        def uri
          @uri
        end
        
        def to_s
          'abcd'
        end
      end
      foo.instance_variable_set(:@uri, active_sources(:find_through_target).uri)
      
      assert_equal(active_sources(:find_through_target).uri, foo.uri)
      assert_equal('abcd', foo.to_s)
      
      result = ActiveSource.find(:all, :find_through => ['http://testvalue.org/pred_find_through', foo])
      assert_equal(1, result.size)
      assert_equal(active_sources(:find_through_test), result[0])
    end
    
    def test_count_through
      result = ActiveSource.count(:find_through => ['http://testvalue.org/pred_find_through', active_sources(:find_through_target).uri])
      assert_equal(1, result)
    end
    
    def test_find_through_props
      result = ActiveSource.find(:all, :find_through => ['http://testvalue.org/pred_find_through', 'the_value'])
      assert_equal(1, result.size)
      assert_equal(active_sources(:find_through_test), result[0])
    end
    
    def test_find_through_fail
      assert_raise(ArgumentError) { ActiveSource.find(:all, :find_through => ['foo:bar', 'bar'], :joins => "LEFT JOIN something") }
      assert_raise(ArgumentError) { ActiveSource.find(:all, :find_through => ['foo:bar', 'bar'], :conditions => ["x = ?", 'bar']) }
    end
    
    def test_find_through_inv
      result = ActiveSource.find(:all, :find_through_inv => ['http://testvalue.org/pred_find_through', active_sources(:find_through_test).uri])
      assert_equal(1, result.size)
      assert_equal(active_sources(:find_through_target), result[0])
    end
    
    def test_find_through_type
      result = ActiveSource.find(:all, :type => active_sources(:find_through_type).uri)
      assert_equal(1, result.size)
      assert_equal(active_sources(:find_through_test), result[0])
    end
    
    def test_singular_accessor
      src = DefinedAccessorTest.new('http://testvalue.org/singular_acc_test')
      assert_equal(nil, src.siglum)
      src.siglum = 'foo'
      src.save!
      assert_equal('foo', src.siglum)
      src.siglum = 'bar'
      assert_equal('bar', src.siglum)
    end
    
    def test_singular_accessor_forcing
      src = DefinedAccessorTest.new('http://testvalue.org/singular_acc_forcing_test')
      assert_equal(nil, src.forcy_single)
      src.forcy_single = active_sources(:testy).uri.to_s
      src.save!
      assert_kind_of(TaliaCore::ActiveSource, src.forcy_single)
      assert_equal(active_sources(:testy).uri, src.forcy_single.uri)
    end
    
    def test_singular_accessor_destroy_dependent
      src = DefinedAccessorTest.new('http://testvalue.org/test_update_attribute_multi_forced')
      assert(src.forcy.blank?)
      src.update_attributes(:siglum => active_sources(:deltest))
      src.save!
      assert(TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
      src.destroy
      assert(!TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
    end
    
    def test_multi_accessor_forcing
      src = DefinedAccessorTest.new('http://testvalue.org/multi_acc_forcing_test')
      assert(src.forcy.blank?)
      src.forcy = [ active_sources(:testy).uri.to_s, active_sources(:testy_two).uri.to_s ]
      src.save!
      assert_property(src.forcy, active_sources(:testy), active_sources(:testy_two))
    end
    
    def test_multi_accessor
      src = DefinedAccessorTest.new('http://testvalue.org/multi_acc_test')
      assert(src.authors.blank?)
      src.authors = [ "foo", "bar", "dingdong" ]
      src.save!
      assert_equal([ "foo", "bar", "dingdong" ].sort, src.authors.sort)
      src.authors = 'bar'
      assert_equal(['bar'], src.authors.values)
    end
    
    def test_multi_accessor_destroy_dependent
      src = DefinedAccessorTest.new('http://testvalue.org/test_update_attribute_multi_forced')
      assert(src.forcy.blank?)
      src.update_attributes(:forcy => [ active_sources(:deltest).uri.to_s ])
      src.save!
      assert(TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
      src.destroy
      assert(!TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
    end
    
    def test_singular_accessor_with_blank
      src = DefinedAccessorTest.new('http://testvalue.org/singular_acc_test')
      assert_equal(nil, src.siglum)
      src.siglum = 'foo'
      src.save!
      assert_equal('foo', src.siglum)
      src.siglum = ''
      assert_equal(nil, src.siglum)
    end
    
    def test_defined_accessor_finder
      src = DefinedAccessorTest.new('http://testvalue.org/singular_find_test')
      src.siglum = 'foo'
      src.save!
      src2 = DefinedAccessorTest.new('http://testvalue.org/singular_find_test2')
      src2.siglum = 'bar'
      src2.save!
      assert_equal(DefinedAccessorTest.find_by_siglum('foo'), [ src ])
    end
    
    def test_autosave_rdf
      src = ActiveSource.new('http://testautosaverdf/')
      assert(src.autosave_rdf?)
      src.autosave_rdf = false
      assert(src.autosave_rdf? == false)
    end

    def test_write_predicate
      src = ActiveSource.new('http://activesourcetest/testwritepredicate')
      src['http://activesourcetest/write_predicate'] << 'foo'
      src.save!
      assert_equal(['foo'], src['http://activesourcetest/write_predicate'].values)
    end

    def test_write_predicate_direct
      src = ActiveSource.new('http://activesourcetest/testwritepredicate')
      src.write_predicate_direct('http://activesourcetest/write_predicate', 'foo')
      assert_equal(['foo'], src['http://activesourcetest/write_predicate'].values)
      assert_equal(['foo'], src.my_rdf['http://activesourcetest/write_predicate'])
    end

    def test_write_direct_new_source
      src = ActiveSource.new('http://activesourcetest/testwritepredicatenewsrc')
      src2 = ActiveSource.new('http://activesourcetest/testwritepredicatenewsrctarg')
      src.write_predicate_direct('http://activesourcetest/write_predicate', src2)
      assert_equal([src2], src['http://activesourcetest/write_predicate'].values)
      assert_equal([src2], src.my_rdf['http://activesourcetest/write_predicate'])
    end


    def test_write_predicate_multi
      src = ActiveSource.new('http://activesourcetest/testwritepredicatemulti')
      src[N::HYPER.multipred] << ['target1', 'target2']
      assert_equal(['target1', 'target2'], src[N::HYPER.multipred].values)
      src.save!
      assert_equal(['target1', 'target2'], src[N::HYPER.multipred].values)
    end

    def test_write_predicate_advanced
      src = ActiveSource.new('http://activesourcetest/testwritepredicateadv')
      target1 = ActiveSource.new('http://activesourcetest/testwritepredtarget1')
      target2 = ActiveSource.new('http://activesourcetest/testwritepredtarget2')
      src[N::HYPER.write_pred] << [target1, target2]
      assert_equal([target1, target2], src[N::HYPER.write_pred].values)
      src.save!
      assert_equal([target1, target2], src[N::HYPER.write_pred].values)
    end

    def test_assign_predicate
      src = ActiveSource.new('http://activesourcetest/testclearpred')
      src['http://activesourcetest/write_predicate'] << 'foo'
      src['http://activesourcetest/write_predicate'] << 'bar'
      src['http://activesourcetest/write_predicate2'] << 'bar'
      src.save!
      assert_equal(2, src['http://activesourcetest/write_predicate'].size)
    end

    def test_double_add_new_source
      src = ActiveSource.new('http://activesourcetest/doubletest')
      src2 = ActiveSource.new('http://activesourcetest/doubletest2')
      src3 = ActiveSource.new('http://activesourcetest/doubletest2')
      src[N::HYPER.bar] << src2
      src[N::HYPER.bar] << src3
      src.save!
      assert_equal([src2, src2], src[N::HYPER.bar].values)
    end

    def test_double_add
      src = ActiveSource.new('http://activesourcetest/doubleadd/test')
      src[N::HYPER.bar] << 'foo'
      src.save!
      src2 =  ActiveSource.find(src.uri)
      src2[N::HYPER.bar] << 'bar'
      src2.save!
      assert_property(ActiveSource.find(src.uri)[N::HYPER.bar], 'foo', 'bar')
    end

    def test_double_add_and_reset
      src = ActiveSource.new('http://activesourcetest/doubleaddload/test')
      src[N::HYPER.bar] << 'foo'
      src.save!
      src2 =  ActiveSource.find(src.uri)
      src2[N::HYPER.bar] << 'bar'
      src2.save!
      src.reset!
      assert_property(src[N::HYPER.bar], 'foo', 'bar')
    end
    
    def test_db_attributes
      assert(ActiveSource.db_attr?(:type))
      assert(ActiveSource.db_attr?('type'))
      assert(!ActiveSource.db_attr?('footype'))
      assert(!ActiveSource.db_attr?('http://www.foobar.org/'))
    end
    
    def test_db_id
      assert(ActiveSource.db_attr?(:id))
      assert(ActiveSource.db_attr?('id'))
      assert_equal(active_sources(:testy)['id'], active_sources(:testy)[:id])
      assert_equal(active_sources(:testy)['id'], active_sources(:testy).id)
    end
    
    def test_expand_uri
      assert_equal(N::LOCAL.foo.to_s, ActiveSource.expand_uri(':foo'))
      assert_equal(N::LOCAL.foo.to_s, ActiveSource.expand_uri('foo'))
      assert_equal(N::LOCAL.foo.to_s, ActiveSource.expand_uri('local:foo'))
      assert_equal(N::RDF.foo.to_s, ActiveSource.expand_uri('rdf:foo'))
      assert_equal('http://barf.org/foo', ActiveSource.expand_uri('http://barf.org/foo'))
    end
    
    def test_update_attributes_on_saved
      src = ActiveSource.new('http://as_test/test_update_attributes_on_saved')
      src.save!
      src.update_attributes(:uri => 'http://as_test/test_update_attributes_on_2', 'rdf:foo' => 'value', N::LOCAL.relatit.to_s => "<#{N::LOCAL + 'attr_on_save_test_dummy'}>" )
      src = ActiveSource.find('http://as_test/test_update_attributes_on_2')
      assert_kind_of(SourceTypes::DummySource, src[N::LOCAL.relatit].first)
      assert_equal(N::LOCAL + 'attr_on_save_test_dummy', src[N::LOCAL.relatit].first.uri)
      assert_equal('value', src[N::RDF.foo].first)
    end
    
    def test_update_attributes_lists
      src = ActiveSource.new('http://as_test/test_update_attributes_on_saved_lists')
      src.update_attributes(N::LOCAL.relatit.to_s => ["<#{N::LOCAL + 'attr_update_test_dummy'}>" , "<:another_attribute_save_dummy>"])
      assert_property(src[N::LOCAL.relatit], N::LOCAL.attr_update_test_dummy, N::LOCAL.another_attribute_save_dummy)
    end
    
    def test_update_attribute_singular
      src = DefinedAccessorTest.new('http://as_test/test_update_attribute_singular')
      src.update_attributes(:siglum => "foo my ass")
      assert_equal('foo my ass', src.siglum)
    end
    
    def test_update_attribute_singular_forced
      src = DefinedAccessorTest.new('http://as_test/test_update_attribute_singular_forced')
      src.update_attributes(:forcy_single => active_sources(:testy).uri.to_s)
      assert_kind_of(TaliaCore::ActiveSource, src.forcy_single)
      assert_equal(active_sources(:testy).uri, src.forcy_single.uri)
    end
    
    def test_update_attribute_singular_destroy
      src = DefinedAccessorTest.new(:uri => 'http://as_test/test_update_attribute_singular_destroy', 
      :siglum => active_sources(:deltest))
      src.save!
      assert(TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
      src.update_attributes(:siglum => "")
      assert(!TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
    end
    
    def test_update_attribute_multi
      src = DefinedAccessorTest.new('http://as_test/test_update_attribute_multi')
      src.update_attributes(:authors => [ "fooby", "barni", "doc garfield" ])
      assert_equal([ "fooby", "barni", "doc garfield" ].sort, src.authors.sort)
    end
    
    def test_update_attribute_multi_forced
      src = DefinedAccessorTest.new('http://testvalue.org/test_update_attribute_multi_forced')
      assert(src.forcy.blank?)
      src.update_attributes(:forcy => [ active_sources(:testy).uri.to_s, active_sources(:testy_two).uri.to_s ])
      src.save!
      assert_property(src.forcy, active_sources(:testy), active_sources(:testy_two))
    end
    
    def test_update_attribute_multi_destroy
      src = DefinedAccessorTest.new(:uri => 'http://as_test/test_update_attribute_multi_destroy', 
      :forcy => active_sources(:deltest))
      src.save!
      assert(TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
      src.update_attributes(:forcy => [])
      assert(!TaliaCore::ActiveSource.exists?(active_sources(:deltest).id))
    end
    
    def test_update_adding
      src = ActiveSource.new('http://as_test/test_update_adding')
      src[N::RDF.something] << 'value1'
      src.update_attributes!('rdf:something' => ['value2', 'value3'])
      assert_property(src[N::RDF.something], 'value1', 'value2', 'value3')
    end
    
    def test_rewrite
      src = ActiveSource.new('http://as_test/test_update_rewrite')
      src[N::RDF.something] << 'value1'
      src.rewrite_attributes!('rdf:something' => ['value2', 'value3'])
      assert_property(src[N::RDF.something], 'value2', 'value3')
    end
    
    def test_rewrite_type
      src = ActiveSource.new('http://as_test/test_update_rewrite_type')
      src.rewrite_attributes!({}) { |src| src.type = 'TaliaCore::DefinedAccessorTest' }
      assert_kind_of(DefinedAccessorTest, ActiveSource.find(src.uri))
    end
    
    def test_rewrite_type
      src = ActiveSource.new('http://as_test/test_update_type')
      src.update_attributes!({}) { |src| src.type = 'TaliaCore::DefinedAccessorTest' }
      assert_kind_of(DefinedAccessorTest, ActiveSource.find(src.uri))
    end
    
    def test_update_static
      src = ActiveSource.new('http://as_test/test_update_static')
      src[N::RDF.something] << 'value1'
      src.save!
      ActiveSource.update(src.uri, 'rdf:something' => ['value2', 'value3'])
      src = ActiveSource.find(src.uri)
      assert_property(src[N::RDF.something], 'value1', 'value2', 'value3')
    end
    
    def test_rewrite_static
      src = ActiveSource.new('http://as_test/test_update_rewrite')
      src[N::RDF.something] << 'value1'
      src.save!
      ActiveSource.rewrite(src.id, 'rdf:something' => ['value2', 'value3'])
      src = ActiveSource.find(src.id)
      assert_property(src[N::RDF.something], 'value2', 'value3')
    end
    
    def test_create_with_attributes
      src = ActiveSource.new(:uri => 'http://as_test/create_with_attributes', ':localthi' => 'value', 'rdf:relatit' => ["<:as_create_attr_dummy_1>", "<:as_create_attr_dummy_1>"])
      assert_equal('http://as_test/create_with_attributes', src.uri)
      assert_equal('value', src[N::LOCAL.localthi].first)
      assert_property(src[N::RDF.relatit], N::LOCAL.as_create_attr_dummy_1, N::LOCAL.as_create_attr_dummy_1)
    end
    
    def test_create_with_attributes_plain_uri
      src = ActiveSource.new(:uri => 'test_create_with_attributes_plain_uri')
      assert_equal(N::LOCAL.test_create_with_attributes_plain_uri, src.uri)
    end
    
    def test_create_source
      src = ActiveSource.create_source(:uri => 'http://as_test/create_with_type', ':localthi' => 'value', 'rdf:relatit' => ["<:as_create_attr_dummy_1>", "<:as_create_attr_dummy_1>"], 'type' => 'TaliaCore::DefinedAccessorTest')
      assert_kind_of(DefinedAccessorTest, src)
      assert_equal('value', src[N::LOCAL.localthi].first)
      assert_property(src[N::RDF.relatit], N::LOCAL.as_create_attr_dummy_1, N::LOCAL.as_create_attr_dummy_1)
      assert_property(src.types, N::TALIA.foo, src.rdf_selftype)
    end
    
    def test_create_for_existing
      src = ActiveSource.create_source(:uri => 'http://as_test/create_forth_and_existing', ':localthi' => 'valueFOOOO', 'rdf:relatit' => ["<:as_create_attr_dummy_1>", "<:as_create_attr_dummy_1>"], 'type' => 'TaliaCore::DefinedAccessorTest')
      src.save!
      assert_equal('valueFOOOO', src[N::LOCAL.localthi].first)
      xml = src.to_xml
      # Quickly change something inside, but leave the URL
      xml.gsub!('valueFOOOO', 'valorz')
      new_src = ActiveSource.create_from_xml(xml, 'duplicates' => 'update')
      # Now test as above
      assert_equal(src.uri.to_s, new_src.uri.to_s)
      assert_equal('valorz', new_src[N::LOCAL.localthi].first)
      assert_property(new_src[N::RDF.relatit], N::LOCAL.as_create_attr_dummy_1, N::LOCAL.as_create_attr_dummy_1)
      assert_property(new_src.types, N::TALIA.foo, new_src.rdf_selftype)
    end
    
    def test_create_multi
      src_attribs = [
        { :uri => N::LOCAL.test_create_multi_stuff, 'rdf:relatit' => [ "<#{N::LOCAL.test_create_multi_stuff_two}>" ], 'type' => 'TaliaCore::DefinedAccessorTest' },
        { :uri => N::LOCAL.test_create_multi_stuff_two, ':localthi' => 'valueFOOOO', 'rdf:relatit' => ["<#{N::LOCAL.test_create_multi_stuff}>"], 'type' => 'TaliaCore::DefinedAccessorTest' }
      ]
      ActiveSource.create_multi_from(src_attribs, :duplicates => :update)
      src = TaliaCore::ActiveSource.find(N::LOCAL.test_create_multi_stuff)
      src_two = TaliaCore::ActiveSource.find(N::LOCAL.test_create_multi_stuff_two)
      assert(src && src_two)
      assert_kind_of(DefinedAccessorTest, src)
      assert_kind_of(DefinedAccessorTest, src_two)
      assert_property(src_two[N::RDF.relatit], N::LOCAL.test_create_multi_stuff)
      assert_property(src[N::RDF.relatit], N::LOCAL.test_create_multi_stuff_two)
      assert_property(src_two[N::LOCAL.localthi], 'valueFOOOO')
    end
    
    
    def test_xml_forth_and_back
      src = ActiveSource.create_source(:uri => 'http://as_test/create_forth_and_back', ':localthi' => 'value', 'rdf:relatit' => ["<:as_create_attr_dummy_1>", "<:as_create_attr_dummy_1>"], 'type' => 'TaliaCore::SourceTypes::DummySource')
      xml = src.to_xml
      assert_kind_of(TaliaCore::SourceTypes::DummySource, src)
      # Quickly change the URI for the new thing
      xml.gsub!(src.uri.to_s, 'http://as_test/create_forth_and_forth')
      # this is for the type attribute in the xml
      xml.gsub!('SourceTypes::DummySource', 'DefinedAccessorTest')
      # The next is for the 'type' semantic triple already existing
      xml.gsub!('DummySource', 'DefinedAccessorTest')
      new_src = ActiveSource.create_from_xml(xml, :duplicates => :update)
      assert_kind_of(TaliaCore::DefinedAccessorTest, new_src)
      # Now test as above
      assert_equal('http://as_test/create_forth_and_forth', new_src.uri.to_s)
      assert_equal('value', new_src[N::LOCAL.localthi].first)
      assert_property(new_src[N::RDF.relatit], N::LOCAL.as_create_attr_dummy_1, N::LOCAL.as_create_attr_dummy_1)
      assert_property(new_src.types, N::TALIA.foo, new_src.rdf_selftype)
    end
    
    def test_create_with_file
      src = ActiveSource.create_source(:uri => 'http://as_test/create_with_file', 'type' => 'TaliaCore::Source', 'files' => {'url' => @test_file })
      assert_equal(1, src.data_records.size)
      src.save!
      assert(!src.data_records.first.new_record?)
      assert_kind_of(DataTypes::XmlData, src.data_records.first)
      File.open(@test_file) do |io|
        assert_equal(src.data_records.first.all_text, io.read)
      end
    end
    
    # Test if accessing the data on a Source works
    def test_data_access
      data = make_data_source.data
      assert_equal(2, data.size)
    end
    
    # Test if accessing the data on a Source works
    def test_data_access_by_type
      data = make_data_source.data("TaliaCore::DataTypes::SimpleText")
      assert_equal(1, data.size)
      assert_kind_of(DataTypes::SimpleText, data.first)
    end
    
    # Test if accessing the data on a Source works
    def test_data_access_by_type_and_location
      data = make_data_source.data("TaliaCore::DataTypes::ImageData", "image.jpg")
      assert_kind_of(DataTypes::ImageData, data)
    end
    
    # Test accessing inexistent data
    def test_data_access_inexistent
      data_source = make_data_source
      data = data_source.data("Foo")
      assert_equal(0, data.size)
      data = data_source.data("SimpleText", "noop.txt")
      assert_nil(data)
    end
    
    def test_update_source_skip
      src = ActiveSource.create_source(:uri => 'http://as_test/update_source_skip', ':localthi' => 'value', 'rdf:somethi' => 'value2', 'type' => 'TaliaCore::Source', 'files' => {'url' => @test_file })
      src.save!
      src.update_source({ ':localthi' => ['value2', 'value3'] }, :skip)
      assert_property(src[N::LOCAL.localthi], 'value')
      assert_property(src[N::RDF.somethi], 'value2')
      assert_equal(1, src.data_records.size)
    end
    
    def test_update_source_skip_dummy
      src = ActiveSource.create_source(:uri => 'http://as_test/update_source_skip_dummy', ':localthi' => 'value', 'rdf:somethi' => 'value2', 'type' => 'TaliaCore::SourceTypes::DummySource')
      src.save!
      assert_kind_of(SourceTypes::DummySource, src)
      src.update_source({ ':localthi' => ['value2', 'value3'] }, :skip)
      assert_property(src[N::LOCAL.localthi], 'value2', 'value3')
      assert_property(src[N::RDF.somethi], 'value2')
    end
    
    def test_update_source_overwrite
      src = ActiveSource.create_source(:uri => 'http://as_test/update_source_overwrite', ':localthi' => 'value', 'rdf:somethi' => 'value2', 'type' => 'TaliaCore::Source', 'files' => {'url' => @test_file })
      src.save!
      new_file = File.join(ActiveSupport::TestCase.fixture_path, 'tiny.jpg')
      src.update_source({ ':localthi' => ['value2', 'value3'] }, :overwrite)
      assert_property(src[N::LOCAL.localthi], 'value2', 'value3')
      assert_property(src[N::RDF.somethi])
      assert_equal(0, src.data_records.size)
    end
    
    def test_update_source_update
      src = ActiveSource.create_source(:uri => 'http://as_test/update_source_update', ':localthi' => 'value', 'rdf:somethi' => 'value2', 'type' => 'TaliaCore::Source', 'files' => {'url' => @test_file })
      src.save!
      new_file = File.join(ActiveSupport::TestCase.fixture_path, 'tiny.jpg')
      src.update_source({ ':localthi' => ['value2', 'value3'], 'files' => {'url' => new_file } }, :update)
      assert_property(src[N::LOCAL.localthi], 'value2', 'value3')
      assert_property(src[N::RDF.somethi], 'value2')
      assert_kind_of(DataTypes::IipData, src.data_records.first)
    end
    
    def test_update_source_add
      src = ActiveSource.create_source(:uri => 'http://as_test/update_source_add', ':localthi' => 'value', 'rdf:somethi' => 'value2', 'type' => 'TaliaCore::Source', 'files' => {'url' => @test_file })
      src.save!
      new_file = File.join(ActiveSupport::TestCase.fixture_path, 'tiny.jpg')
      src.update_source({ ':localthi' => ['value2', 'value3'], 'files' => {'url' => new_file } }, :add)
      assert_property(src[N::LOCAL.localthi], 'value', 'value2', 'value3')
      assert_property(src[N::RDF.somethi], 'value2')
      # Expect 2 records: The original, the iip image and the orig_image
      assert_equal(3, src.data_records.size)
    end
    
    def test_destroy_source
      # Set up some sources that are interlinked
      sources = (0..2).collect do |idx|
        src = ActiveSource.new("http://as_test/destroy_source_#{idx}")
        src.save!
        src
      end
      
      sources[0][N::TALIA.test_pred] << sources[1]
      sources[0][N::TALIA.test_pred] << sources[2]
      sources[1][N::TALIA.testy_pred] << sources[0]
      sources[1][N::TALIA.testy_pred] << sources[2]
      
      sources.each { |s| s.save! }
      
      # Check if everything is set up correctly
      assert_property(sources[0][N::TALIA.test_pred], sources[1], sources[2])
      assert_property(sources[1][N::TALIA.testy_pred], sources[0], sources[2])
      
      # Destroy one source
      destroyed_id = sources[1].id
      sources[1].destroy
      
      # Check if it took all the links with it
      test_source = TaliaCore::ActiveSource.find(sources[0].id)
      assert_property(test_source[N::TALIA.test_pred], sources[2]) # This one should have the "destroyed" connection removed
      # All relations related to that source should be gone
      assert_equal(0, TaliaCore::SemanticRelation.all(:conditions => { :subject_id => destroyed_id }).size)
      assert_equal(0, TaliaCore::SemanticRelation.all(:conditions => { :object_id => destroyed_id }).size)
      # The source should be gone
      assert(!TaliaCore::ActiveSource.exists?(sources[1].uri))
      # The RDF should be gone
      forward_result = ActiveRDF::Query.new(N::URI).select(:thing).where(sources[0], N::TALIA.test_pred, :thing).execute
      assert_equal(1, forward_result.size, "Found more than one : #{forward_result.inspect}")
      backward_result = ActiveRDF::Query.new(N::URI).select(:thing).where(sources[1], :all, :thing).execute
      assert_equal(0, backward_result.size)
    end
    
    def test_to_uri
      src = ActiveSource.new('http://xsource/has_type_test')
      assert_equal(N::URI.new('http://xsource/has_type_test'), src.to_uri)
    end
    
    def test_has_defined_property
      assert(DefinedAccessorTest.defined_property?(:siglum))
      assert(!DefinedAccessorTest.defined_property?(:title))
    end
    
    def test_no_defined_property
      assert(!ActiveSource.defined_property?(:siglum))
    end
    
    def test_has_defined_property_on_subclass
      assert(DefinedAccessorSubTest.defined_property?(:title))
      assert(DefinedAccessorSubTest.defined_property?(:siglum))
    end
    
    def test_naked_has_defined_property_on_subclass
      assert(DefinedAccessorSubNaked.defined_property?(:siglum))
    end
    
    def test_singular_property_bracket_access
      singi = DefinedAccessorTest.new('http://www.test.org/singular_property_bracket_access')
      singi.siglum = 'foo'
      assert_equal('foo', singi[:siglum])
      singi[:siglum] = 'bar'
      assert_equal('bar', singi.siglum)
    end
    
    def test_singular_property_with_source
      related = ActiveSource.new('http://www.test.org/prop_with_sources_friend/')
      related.save!
      singi = DefinedAccessorTest.new('http://www.test.org/singular_property_with_source')
      singi.siglum = related
      singi.save!
      singi = DefinedAccessorTest.find(singi.id)
      assert_kind_of(ActiveSource, singi.siglum)
      assert_equal(related.uri, singi.siglum.uri)
    end
    
    def test_singular_property_with_uri
      related = ActiveSource.new('http://www.test.org/prop_with_uri_friend/')
      related.save!
      singi = DefinedAccessorTest.new('http://www.test.org/singular_property_with_uri')
      singi.siglum = related.to_uri
      singi.save!
      singi = DefinedAccessorTest.find(singi.id)
      assert_kind_of(ActiveSource, singi.siglum)
      assert_equal(related.uri, singi.siglum.uri)
    end
    
    def test_assign_throug_uri
      related = ActiveSource.new('http://www.test.org/assign_through_friend/')
      related.save!
      src = ActiveSource.new('http://www.test.org/assign_throug_uri')
      src[N::RDF.foo] = related.to_uri
      src.save!
      src = ActiveSource.find(src.id)
      assert_property(src[N::RDF.foo], related)
    end
    
    def test_autofill_url
      new_thing = DefinedAccessorTest.new
      assert(!new_thing.uri.blank?)
    end
    
    def test_autofill_url_params
      new_thing = DefinedAccessorTest.new(:siglumm => "foo")
      assert(!new_thing.uri.blank?)
    end
    
    def test_autofill_url_params_and_save
      new_thing = DefinedAccessorTest.new(:siglumm => "foo")
      new_thing.save!
      assert(DefinedAccessorTest.exists?(new_thing.uri))
    end
    
    def test_autofill_url_not
      new_thing = DefinedAccessorSubNaked.new(:siglum => "foo")
      assert(new_thing.uri.blank?)
    end
    
    def test_manual_url_and_save
      new_thing = DefinedAccessorTest.new(:siglumm => "foo", :uri => "http://foobar.com")
      new_thing.save!
      assert(DefinedAccessorTest.exists?(new_thing.uri))
    end
    
    def test_manual_property
      new_thing = DefinedAccessorTest.new(:blinko => "Bing!")
      assert_equal(new_thing.blinko, "Bing!")
    end
    
    def test_reload
      new_thing = ActiveSource.new('http://testme/testing_reload')
      new_thing.save!
      assert_property(new_thing[N::RDF.somethink])
      other_thing = ActiveSource.find(new_thing.id)
      other_thing[N::RDF.somethink] << "Bongo"
      other_thing.save!
      new_thing.reload
      assert_property(new_thing[N::RDF.somethink], "Bongo")
    end
    
    private
    
    def make_data_source
      data_source = ActiveSource.new("http://www.test.org/source_with_data")
      text = DataTypes::SimpleText.new
      text.location = "text.txt"
      image = DataTypes::ImageData.new
      image.location = "image.jpg"
      data_source.data_records << text
      data_source.data_records << image
      data_source.save!
      data_source
    end
    
    
  end
  
end
