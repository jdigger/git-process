require 'git-process/git_lib'

class GitLibStub
  include GitProc::GitLib


  def initialize(workdir = Dir.mktmpdir, log_level = Logger::ERROR)
    @logger = Logger.new(STDOUT)
    @logger.level = log_level || Logger::WARN
    @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    f = Logger::Formatter.new
    @logger.formatter = proc do |_, _, _, msg|
      "#{msg}\n"
    end

    @workdir = workdir
    if workdir
      if File.directory?(File.join(workdir, '.git'))
        logger.debug { "Opening existing repository at #{workdir}" }
      else
        logger.info { "Initializing new repository at #{workdir}" }
        command(:init)
      end
    end
  end


  def workdir
    @workdir
  end


  def logger
    @logger
  end
end
