# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'fileutils'

module TaliaCore
  module DataTypes
    
    # This is used for "delayed" copy operations. Basically this will created
    # a file called "delayed_copy.sh" in the RAILS_ROOT, which can later be
    # run as a bash script. This will allow the user to run the
    # copy operation and be potentially faster than using the builtin copy
    # operations (especially using JRuby)
    class DelayedCopier
      
      # Returns (and creates, if necessary) the file to write the delayed 
      # copy operations to
      def self.delayed_copy_file
        @delayed_copy_file ||= begin
          backup_file if(File.exists?(delay_file_name))
          file = File.open(delay_file_name, 'w')
          file.puts('#!/bin/bash')
          file
        end
      end
      
      # This writes the "cp" command to the output script. It will also
      # add a "mkdir" command to create the directory for the target file,
      # if necessary.
      #
      # At the moment,
      # this will always use UNIX-style "cp" and "mkdir" commands.
      def self.cp(source, target)
        # We use the << in-place string concenation, 'cause if there
        # are a lot of files, it really makes a speed difference
        unless(dir_seen?(File.expand_path(target)))
          mkdir_string = 'mkdir -vp "'
          mkdir_string << File.dirname(File.expand_path(target))
          mkdir_string << '"'
          delayed_copy_file.puts(mkdir_string)
        end
        cp_string = 'cp -v "'
        cp_string << File.expand_path(source)
        cp_string << '" "'
        cp_string << File.expand_path(target)
        cp_string << '"'
        delayed_copy_file.puts(cp_string)
        delayed_copy_file.flush
      end
      
      # Close the delayed copy file
      def self.close
        if(@delayed_copy_file)
          @delayed_copy_file.close
          @delayed_copy_file = nil
        end
      end
      
      private
      
      # Returns true if the directory has already been seen by
      # the copier before.
      def self.dir_seen?(directory)
        @seen_dirs = {}
        return true if(@seen_dirs[directory])
        @seen_dirs[directory] = true
        false
      end
      
      # The file name for the delayed copy (the file where the
      # commands are written out)
      def self.delay_file_name
        File.join(RAILS_ROOT, 'delayed_copy.sh')
      end
      
      # Backs up an existing file with delayed commands, if necessary
      def self.backup_file
        round = 1
        file_name = 'nil'
        while(File.exists?(file_name = File.join(RAILS_ROOT, "delayed_copy_old_#{round}.sh")))
          round += 1
        end
        FileUtils.mv(delay_file_name, file_name) 
      end
      
    end
    
  end
end