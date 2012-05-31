require File.expand_path('../../lib/git-process', __FILE__)

describe Git::Process do

  describe "when creating" do

    it "should hand over a valid repo" do
      repo = Git::Process.repo("#{File.dirname(__FILE__)}/..")
      repo.empty?.should be_false
    end
    
  end

end
