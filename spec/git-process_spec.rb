require 'git-process/git-process'
require 'GitRepoHelper'

describe GitProc::Process do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


end
