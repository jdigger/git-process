require 'FileHelpers'
require 'git-lib'

module GitRepoHelper


  def gitlib
    @gitlib ||= Git::GitLib.new(tmpdir, :log_level => log_level)
  end


  def gitprocess
    @gitprocess ||= Git::Process.new(nil, gitlib)
  end


  def tmpdir
    @tmpdir ||= Dir.mktmpdir
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
    Dir.chdir(gitlib.workdir) do |dir|
      file_names.each do |fn|
        gitlib.logger.debug {"Creating #{dir}/#{fn}"}
        FileUtils.touch fn
      end
    end
    gitlib.add(file_names)
  end



  def change_file_and_commit(filename, contents, lib = gitlib)
    Dir.chdir(lib.workdir) do
      File.open(filename, 'w') {|f| f.puts contents}
    end
    lib.add(filename)
    lib.commit("#{filename} - #{contents}")
  end


  def clone(branch='master', &block)
    td = Dir.mktmpdir
    gl = Git::GitLib.new(td, :log_level => log_level)
    gl.add_remote('origin', "file://#{tmpdir}")
    gl.fetch
    gl.checkout(branch, :new_branch => "origin/#{branch}")
    if block_given?
      begin
        block.arity < 1 ? gl.instance_eval(&block) : block.call(gl)
      rescue => exp
        rm_rf(gl.workdir)
        raise exp
      end
      nil
    else
      gl
    end
  end

end
