require 'git-process/git_abstract_merge_error_builder'
require 'git-process/git_lib'
require 'FileHelpers'

describe GitProc::AbstractMergeErrorBuilder do

  def builder
    @builder ||= GitProc::AbstractMergeErrorBuilder.new(gitlib, '', nil)
  end


  after(:each) do
    rm_rf(gitlib.workdir)
  end


  def gitlib
    if @lib.nil?
      @lib = GitProc::GitLib.new(Dir.mktmpdir, :log_level => Logger::ERROR)
      @lib.config.rerere_enabled = true
      @lib.config.rerere_autoupdate = true
      mock_status(@lib)
    end
    @lib
  end


  def metaclass(obj)
    class << obj
      self
    end
  end


  def mock_status(lib)
    spec = self
    metaclass(lib).send(:define_method, :status) do
      @status ||= spec.double('status')
    end
  end


  def match_commands(expected)
    commands = builder.commands
    expected.each do |e|
      commands.slice!(0).should == e
    end
    commands.should be_empty
  end


  it "merged with rerere.enabled false" do
    gitlib.config.rerere_enabled = false
    gitlib.status.stub(:unmerged).and_return(['a', 'b c'])
    gitlib.status.stub(:modified).and_return(['a', 'b c'])
    gitlib.status.stub(:added).and_return([])

    builder.resolved_files.should == []
    builder.unresolved_files.should == ['a', 'b c']
    c = [
        'git config --global rerere.enabled true',
        'git mergetool a b\ c',
        '# Verify \'a\' merged correctly.',
        '# Verify \'b c\' merged correctly.',
        'git add a b\ c',
    ]
    match_commands c
  end


  it "merged with rerere.enabled true and auto-handled AND autoupdated a file" do
    gitlib.config.rerere_enabled = true
    gitlib.config.rerere_autoupdate = true
    gitlib.status.stub(:unmerged).and_return(['a', 'b c'])
    gitlib.status.stub(:modified).and_return(['a', 'b c'])
    gitlib.status.stub(:added).and_return([])
    builder.stub(:error_message).and_return("\nResolved 'a' using previous resolution.\n")

    builder.resolved_files.should == %w(a)
    builder.unresolved_files.should == ['b c']
    c = [
        '# Verify that \'rerere\' did the right thing for \'a\'.',
        'git mergetool b\ c',
        '# Verify \'b c\' merged correctly.',
        'git add b\ c',
    ]
    match_commands c
  end


  it "merged with rerere.enabled true and auto-handled and not autoupdated a file" do
    gitlib.config.rerere_autoupdate = false
    gitlib.status.stub(:unmerged).and_return(['a', 'b c'])
    gitlib.status.stub(:modified).and_return(['a', 'b c'])
    gitlib.status.stub(:added).and_return([])
    builder.stub(:error_message).and_return("\nResolved 'a' using previous resolution.\n")

    builder.resolved_files.should == %w(a)
    builder.unresolved_files.should == ['b c']
    c = [
        '# Verify that \'rerere\' did the right thing for \'a\'.',
        'git add a',
        'git mergetool b\ c',
        '# Verify \'b c\' merged correctly.',
        'git add b\ c',
    ]
    match_commands c
  end


  it "merged with a file added in both branches" do
    gitlib.config.rerere_autoupdate = false
    gitlib.status.stub(:unmerged).and_return(%w(a))
    gitlib.status.stub(:modified).and_return(%w(b))
    gitlib.status.stub(:added).and_return(%w(a c))

    builder.resolved_files.should == %w()
    builder.unresolved_files.should == %w(a)
    c = [
        '# \'a\' was added in both branches; Fix the conflict.',
        'git add a',
    ]
    match_commands c
  end

end
