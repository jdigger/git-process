require 'FileHelpers'
require 'git-lib'

module GitRepoHelper


  def gitlib
    @gitlib ||= Git::GitLib.new(tmpdir, :log_level => Logger::ERROR)
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


  def logger
    unless @logger
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      f = Logger::Formatter.new
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity[0..0]}: #{datetime.strftime(@logger.datetime_format)}: #{msg}\n"
      end
    end
    @logger
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



  def change_file_and_commit(filename, contents)
    Dir.chdir(gitlib.workdir) do
      File.open(filename, 'w') {|f| f.puts contents}
    end
    gitlib.add(filename)
    gitlib.commit("#{filename} - #{contents}")
  end

end
