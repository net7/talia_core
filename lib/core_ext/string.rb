class String
  # Transform the current string into a permalink.
  def to_permalink
    self.gsub(/\W+/, ' ').strip.downcase.titleize.gsub(/\ +/, '_')
  end
  
  # Give a URI object created from the current string
  def to_uri
    N::URI.new(self)
  end
  
end