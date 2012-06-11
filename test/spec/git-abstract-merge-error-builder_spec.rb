require File.expand_path('../../../lib/git-abstract-merge-error-builder', __FILE__)
require File.expand_path('../../../lib/git-lib', __FILE__)
require File.expand_path('../../FileHelpers', __FILE__)

describe Git::AbstractMergeErrorBuilder do

  before(:each) do
    @builder = Object.new
    @builder.extend(Git::AbstractMergeErrorBuilder)
    @lib = double('lib')
    @builder.stub(:lib).and_return(@lib)
    @builder.stub(:continue_command).and_return(nil)
    @lib.stub(:rerere_enabled?).and_return(true)
    @lib.stub(:rerere_autoupdate?).and_return(true)
    @status = double('status')
    @lib.stub(:status).and_return(@status)
  end


  it "merged with rerere.enabled false" do
    @lib.stub(:rerere_enabled?).and_return(false)
    @status.stub(:unmerged).and_return(['a', 'b c'])
    @status.stub(:modified).and_return(['a', 'b c'])
    @builder.stub(:error_message).and_return('')

    @builder.resolved_files.should == []
    @builder.unresolved_files.should == ['a', 'b c']
    commands = @builder.commands
    commands.slice!(0).should == 'git config --global rerere.enabled true'
    commands.slice!(0).should == 'git mergetool a b\ c'
    commands.slice!(0).should == '# Verify \'a\' merged correctly.'
    commands.slice!(0).should == '# Verify \'b c\' merged correctly.'
    commands.slice!(0).should == 'git add a b\ c'
    commands.should be_empty
  end


  it "merged with rerere.enabled true and auto-handled AND autoupdated a file" do
    @status.stub(:unmerged).and_return(['a', 'b c'])
    @status.stub(:modified).and_return(['a', 'b c'])
    @builder.stub(:error_message).and_return("\nResolved 'a' using previous resolution.\n")

    @builder.resolved_files.should == ['a']
    @builder.unresolved_files.should == ['b c']
    commands = @builder.commands
    commands.slice!(0).should == '# Verify that \'rerere\' did the right thing for \'a\'.'
    commands.slice!(0).should == 'git mergetool b\ c'
    commands.slice!(0).should == '# Verify \'b c\' merged correctly.'
    commands.slice!(0).should == 'git add b\ c'
    commands.should be_empty
  end


  it "merged with rerere.enabled true and auto-handled and not autoupdated a file" do
    @lib.stub(:rerere_autoupdate?).and_return(false)
    @status.stub(:unmerged).and_return(['a', 'b c'])
    @status.stub(:modified).and_return(['a', 'b c'])
    @builder.stub(:error_message).and_return("\nResolved 'a' using previous resolution.\n")

    @builder.resolved_files.should == ['a']
    @builder.unresolved_files.should == ['b c']
    commands = @builder.commands
    commands.slice!(0).should == '# Verify that \'rerere\' did the right thing for \'a\'.'
    commands.slice!(0).should == 'git add a'
    commands.slice!(0).should == 'git mergetool b\ c'
    commands.slice!(0).should == '# Verify \'b c\' merged correctly.'
    commands.slice!(0).should == 'git add b\ c'
    commands.should be_empty
  end

end
