# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

# Patches a problem that prevents the default rake unit test task working nicely with the
# JDBC adapter. Note that for this to work correctly, the database type must be set
# to "mysql" instead of "jdbcmysql"

if((RUBY_PLATFORM =~ /java/) && defined?(ActiveRecord::ConnectionAdapters::JdbcAdapter))

  require 'jdbc_adapter/jdbc_mysql'

  assit(defined?(JdbcSpec::MySQL))

  module JdbcSpec # :nodoc:
    module MySQL # :nodoc: 

      alias_method :real_recreate_database, :recreate_database
      def recreate_database(name, dummy = nil) # :nodoc:
        real_recreate_database(name)
      end

    end
  end

end