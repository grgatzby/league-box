# Monkey patch to fix URI.decode deprecation in Ruby 3.0+
# CarrierWave's Cloudinary integration still uses URI.decode which was removed
require 'cgi'

module URI
  def self.decode(str)
    CGI.unescape(str)
  end
end
