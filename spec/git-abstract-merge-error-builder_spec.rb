require 'git-process/git-abstract-merge-error-builder'

describe GitProc::AbstractMergeErrorBuilder do

  def builder
    unless @builder
      @builder = Object.new
      @builder.extend(GitProc::AbstractMergeErrorBuilder)
      @builder.stub(:lib).and_return(lib)
      @builder.stub(:continue_command).and_return(nil)
      @builder.stub(:error_message).and_return('')
    end
    @builder
  end


  def lib
    unless @lib
      @lib = double('lib')
      @lib.stub(:rerere_enabled?).and_return(true)
      @lib.stub(:rerere_autoupdate?).and_return(true)
      @lib.stub(:status).and_return(status)
    end
    @lib
  end


  def status
    unless @status
      @status = double('status')
      @status.stub(:unmerged).and_return([])
      @status.stub(:modified).and_return([])
      @status.stub(:added).and_return([])
    end
    @status
  end


  def match_commands(expected)
    commands = builder.commands
    expected.each do |e|
      commands.slice!(0).should == e
    end
    commands.should be_empty
  end


  it "merged with rerere.enabled false" do
    lib.stub(:rerere_enabled?).and_return(false)
    status.stub(:unmerged).and_return(['a', 'b c'])
    status.stub(:modified).and_return(['a', 'b c'])

    builder.resolved_files.should == []
    builder.unresolved_files.should == ['a', 'b c']
    match_commands [
      'git config --global rerere.enabled true',
      'git mergetool a b\ c',
      '# Verify \'a\' merged correctly.',
      '# Verify \'b c\' merged correctly.',
      'git add a b\ c',
    ]
  end


  it "merged with rerere.enabled true and auto-handled AND autoupdated a file" do
    status.stub(:unmerged).and_return(['a', 'b c'])
    status.stub(:modified).and_return(['a', 'b c'])
    builder.stub(:error_message).and_return("\nResolved 'a' using previous resolution.\n")

    builder.resolved_files.should == ['a']
    builder.unresolved_files.should == ['b c']
    match_commands [
      '# Verify that \'rerere\' did the right thing for \'a\'.',
      'git mergetool b\ c',
      '# Verify \'b c\' merged correctly.',
      'git add b\ c',
    ]
  end


  it "merged with rerere.enabled true and auto-handled and not autoupdated a file" do
    lib.stub(:rerere_autoupdate?).and_return(false)
    status.stub(:unmerged).and_return(['a', 'b c'])
    status.stub(:modified).and_return(['a', 'b c'])
    builder.stub(:error_message).and_return("\nResolved 'a' using previous resolution.\n")

    builder.resolved_files.should == ['a']
    builder.unresolved_files.should == ['b c']
    match_commands [
      '# Verify that \'rerere\' did the right thing for \'a\'.',
      'git add a',
      'git mergetool b\ c',
      '# Verify \'b c\' merged correctly.',
      'git add b\ c',
    ]
  end


  it "merged with a file added in both branches" do
    lib.stub(:rerere_autoupdate?).and_return(false)
    status.stub(:unmerged).and_return(['a'])
    status.stub(:modified).and_return(['b'])
    status.stub(:added).and_return(['a', 'c'])

    builder.resolved_files.should == []
    builder.unresolved_files.should == ['a']
    match_commands [
      '# \'a\' was added in both branches; Fix the conflict.',
      'git add a',
    ]
  end

end
