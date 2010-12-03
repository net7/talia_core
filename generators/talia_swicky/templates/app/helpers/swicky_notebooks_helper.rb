# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'digest/md5'
module SwickyNotebooksHelper
  
  # Wraps the given element into an <div class=""
  def thctag(url, content_or_options_with_block=nil, options=nil, &block)
    if(block)
      content_tag(:div, thctag_options(url, content_or_options_with_block), nil, true, &block)
    else
      content_tag(:div, content_or_options_with_block, thctag_options(url, options))
    end
  end
  
  private
  
  # Updates the given options hash for the thctag
  def thctag_options(url, options)
    options ||= {}
    options.to_options!
    if(options[:class])
      options[:class] << " THCContent"
    else
      options[:class] = "THCContent"
    end
    options[:id] = ('h_' << Digest::MD5.hexdigest(url))
    options[:about] = url
    options
  end
  
end
