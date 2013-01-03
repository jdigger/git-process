$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '../lib')

require 'GitRepoHelper'

RSpec.configure do |config|
  config.include GitRepoHelper
end
