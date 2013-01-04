$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '../lib')

require 'GitRepoHelper'
require 'pull_request_helper'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.include GitRepoHelper, :git_repo_helper

  config.before(:each, :git_repo_helper) do
    create_files(%w(.gitignore))
    gitlib.commit('initial')
  end


  config.after(:each, :git_repo_helper) do
    rm_rf(gitlib.workdir)
  end

end
