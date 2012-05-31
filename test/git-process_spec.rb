require File.expand_path('../../lib/git-process', __FILE__)
require File.expand_path('../FileHelpers', __FILE__)

describe Git::Process do

  before(:each) do
    @tmpdir = Dir.mktmpdir
  end

  after(:each) do
    rm_rf(@tmpdir)
  end

  describe "when creating" do

    before(:each) do
      @gp = Git::Process.create(@tmpdir)
    end

    it "should hand over a valid repo" do
      @gp.repo.empty?.should be_true
    end

  end

end
