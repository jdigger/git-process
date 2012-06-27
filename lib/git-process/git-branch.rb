module Git

  class GitBranch
    include Comparable

    attr_reader :name

    def initialize(name, current, lib)
      if (/^remotes\// =~ name)
        @name = name[8..-1]
        @remote = true
      else
        @name = name
        @remote = false
      end
      @current = current
      @lib = lib
    end


    def current?
      @current
    end


    def remote?
      @remote
    end


    def local?
      !@remote
    end


    def to_s
      name
    end


    def sha
      @sha ||= @lib.command('rev-parse', name)
    end


    def <=>(other)
      self.name <=> other.name
    end


    def is_ahead_of(base_branch_name)
      @lib.command('rev-list', ['-1', '--oneline', "#{base_branch_name}..#{@name}"]) != ''
    end


    def delete(force = false)
      @lib.command(:branch, [force ? '-D' : '-d', @name])
    end


    def rename(new_name)
      @lib.command(:branch, ['-m', @name, new_name])
    end


    def contains_all_of(branch_name)
      @lib.command('rev-list', ['-1', '--oneline', branch_name, "^#{@name}"]) == ''
    end


    def checkout_to_new(new_branch, opts = {})
      args = opts[:no_track] ? ['--no-track'] : []
      args << '-b' << new_branch << @name
      @lib.command(:checkout, args)
    end

  end

end