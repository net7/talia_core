require 'oai'

module TaliaCore
  module Oai
    
    # Basic OAI Model for ActiveSources. This provides basic OAI functionality
    # on ActiveSource in the same way the ActiveRecordWrapper provides the
    # functionality on ActiveRecord.
    #
    # All #find() and related calls will "wrap" the ActiveSource models using
    # using the ActiveSourceOaiAdapter class. You may provide your own adapter
    # class if needed.
    class ActiveSourceModel < OAI::Provider::Model
      
      attr_accessor :model_adapter
      
      def initialize(model_adapter = ActiveSourceOaiAdapter)
        @model_adapter = (model_adapter || ActiveSourceOaiAdapter)
        @timestamp_field = "created_at"
        @limit = 20
      end
      
      def earliest
        select_first_or_last('asc').send(timestamp_field)
      end
      
      def latest
        select_first_or_last('desc').send(timestamp_field)
      end
      
      def last_id(options)
        select_first_or_last('desc', options).id
      end
      
      def sets
        raise OAI::SetException # TODO: Support sets
      end
      
      def find(selector, options = {})
        return select_partial(options[:resumption_token]) if(options[:resumption_token])
        
        conditions = sql_conditions(options)
       
        if(selector == :first)
          #model_adapter.get_wrapper_for(ActiveSource.find(selector, :prefetch_relations => true, :conditions => conditions))
          model_adapter.get_wrapper_for(Source.find(selector, :prefetch_relations => true, :conditions => conditions))
        elsif(selector == :all)
          select_partial(OAI::Provider::ResumptionToken.new(last_id(conditions), options.merge(:last => 0)))
        else
          #model_adapter.get_wrapper_for(ActiveSource.find(selector, :prefetch_relations => true, :conditions => conditions))
          model_adapter.get_wrapper_for(Source.find(selector, :prefetch_relations => true, :conditions => conditions))
        end
      rescue ActiveRecord::RecordNotFound
        nil
      end
      
      private
      
      # Selects a partial result set from a resumption token
      def select_partial(token)
        token = OAI::Provider::ResumptionToken.parse(token) if(token.is_a?(String))
        
        conditions = token_conditions(token)
        #total = ActiveSource.count(:id, :conditions => conditions)
        total = Source.count(:id, :conditions => conditions)
        
        return [] if(total == 0)
        
        #records = ActiveSource.find(:all, :conditions => token_conditions(token),
        records = Source.find(:all, :conditions => token_conditions(token),
          :limit => @limit,
          :order => 'id asc',
          :prefetch_relations => true
        )
        raise(OAI::ResumptionTokenException) unless(records)
        
        last_id = records.last.id
        OAI::Provider::PartialResult.new(model_adapter.get_wrapper_for(records), token.next(last_id))
      end
      
      def select_first_or_last(order, conditions = nil)
        select_options = { :select => "id, #{timestamp_field}", :order => "#{timestamp_field} #{order}" }
        select_options[:conditions] = conditions if(conditions)
        #result = TaliaCore::ActiveSource.find(:first, select_options)
        result = TaliaCore::Source.find(:first, select_options)
        raise OAI::NoMatchException if result.nil? 
        result
      end
      
      # Sql condition for the given token
      def token_conditions(token)
        sql = sql_conditions(token.to_conditions_hash)
        sql_add_fragment_to(sql, 'id > ?', token.last) if(token.last != 0)
        sql
      end
      
      # build a sql conditions statement from an OAI options hash
      def sql_conditions(opts)
        from = Time.parse(opts[:from].to_s).utc
        untl = Time.parse(opts[:until].to_s).utc
        sql = ["#{timestamp_field} >= ? AND #{timestamp_field} <= ?", from, untl]
        
        return sql
      end
      
      # Adds the given fragment to the sql string and adds the vars to the
      # variables that are present for the sql. The old_fragment ist an array
      # with an SQL string template and following variables, as used by 
      # ActiveRecord
      def sql_add_fragment_to(old_fragment, new_frag, *vars)
        old_fragment[0] << ' AND ('
        old_fragment[0] << new_frag
        old_fragment[0] << ')'
        old_fragment.concat(vars)
      end
      
    end
    
  end
end
