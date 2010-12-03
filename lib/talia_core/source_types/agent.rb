# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module SourceTypes

    # Some item that "has the power to act". This can either be a person or another
    # entity, like an institution or a corporation
    class Agent < Source

      has_rdf_type N::DCT.Agent

      singular_property :name, N::DCNS.title
      singular_property :description, N::DCNS.description

    end

  end
end