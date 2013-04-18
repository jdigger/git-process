# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'logger'

module GitProc

  #
  # Provides a Logger for Git commands
  #
  class GitLogger

    DEBUG = Logger::DEBUG
    INFO = Logger::INFO
    WARN = Logger::WARN
    ERROR = Logger::ERROR


    def initialize(log_level = nil, out = STDOUT)
      if out.nil?
        @logger = ::Logger.new(RUBY_PLATFORM =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
      else
        @logger = ::Logger.new(out)
      end
      @logger.level = log_level.nil? ? GitLogger::WARN : log_level
      @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
      @logger.formatter = proc do |_, _, _, msg|
        "#{msg}\n"
      end
    end


    def level
      @logger.level
    end


    def debug(msg = nil, &block)
      if msg.nil?
        @logger.debug(&block)
      else
        @logger.debug(msg)
      end
    end


    def info(msg = nil, &block)
      if msg.nil?
        @logger.info(&block)
      else
        @logger.info(msg)
      end
    end


    def warn(msg = nil, &block)
      if msg.nil?
        @logger.send(:warn, &block)
      else
        @logger.send(:warn, msg)
      end
    end


    def error(msg = nil, &block)
      if msg.nil?
        @logger.error(&block)
      else
        @logger.error(msg)
      end
    end

  end

end
