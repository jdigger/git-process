require 'tmpdir'
require 'FileHelpers'
require 'git-process/git_process'
include GitProc

module GitRepoHelper

  def gitprocess
    if @gitprocess.nil? and respond_to?(:create_process)
      @gitprocess = create_process(gitlib, :log_level => log_level)
    end
    @gitprocess
  end


  def gitlib
    if @gitlib.nil?
      if @gitprocess.nil?
        @gitlib = create_gitlib(Dir.mktmpdir, :log_level => log_level)
      else
        @gitlib = gitprocess.gitlib
      end
    end
    @gitlib
  end


  def config
    gitlib.config
  end


  def remote
    gitlib.remote
  end


  def commit_count
    gitlib.log_count
  end


  def log_level
    Logger::ERROR
  end


  def logger
    gitlib.logger
  end


  def create_files(file_names)
    GitRepoHelper.create_files gitlib, file_names
  end


  def self.create_files(gitlib, file_names)
    Dir.chdir(gitlib.workdir) do |dir|
      file_names.each do |fn|
        gitlib.logger.debug { "Creating #{dir}/#{fn}" }
        FileUtils.touch fn
      end
    end
    gitlib.add(file_names)
  end


  def change_file(filename, contents, lib = gitlib)
    Dir.chdir(lib.workdir) do
      File.open(filename, 'w') { |f| f.puts contents }
    end
  end


  def change_file_and_add(filename, contents, lib = gitlib)
    change_file(filename, contents, lib)
    lib.add(filename)
  end


  def change_file_and_commit(filename, contents, lib = gitlib)
    change_file_and_add(filename, contents, lib)
    lib.commit("#{filename} - #{contents}")
  end


  def create_gitlib(dir, opts)
    git_lib = GitLib.new(dir, opts)
    git_lib.config['user.email'] = 'test.user@test.com'
    git_lib.config['user.name'] = 'test user'
    git_lib
  end


  def clone_repo(branch='master', remote_name = 'origin', &block)
    td = Dir.mktmpdir

    logger.debug { "Cloning '#{gitlib.workdir}' to '#{td}'" }

    gl = create_gitlib(td, :log_level => logger.level)
    gl.remote.add(remote_name, "file://#{gitlib.workdir}")
    gl.fetch(remote_name)

    if branch == 'master'
      gl.reset("#{remote_name}/#{branch}", :hard => true)
    else
      gl.checkout(branch, :new_branch => "#{remote_name}/#{branch}")
    end

    if block_given?
      begin
        block.arity < 1 ? gl.instance_eval(&block) : block.call(gl)
      ensure
        rm_rf(gl.workdir)
      end
      nil
    else
      gl
    end
  end

end
