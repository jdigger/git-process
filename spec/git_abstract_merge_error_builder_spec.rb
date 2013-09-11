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


  it "merged with a file added in both branches" do
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
