require 'git-process/git-branch'

module GitProc

  class GitBranches
    include Enumerable

    def initialize(lib)
      @lib = lib
      branch_lines = lib.branch(nil, :all => true, :no_color => true).split("\n")
      @items = SortedSet.new
      branch_lines.each do |bl|
        @items << GitBranch.new(bl[2..-1], bl[0..0] == '*', lib)
      end
    end


    def <<(item)
      @items << item
    end


    def each(&block)
      @items.each {|b| block.call(b)}
    end


    def names
      @items.map {|b| b.name}
    end


    def current
      @items.find {|b| b.current? }
    end


    def parking
      @items.find {|b| b.name == '_parking_' }
    end


    def include?(branch_name)
      @items.find {|b| b.name == branch_name} != nil
    end


    def [](branch_name)
      branch_name = current.name if branch_name == 'HEAD'
      br = @items.find {|b| b.name == branch_name}
      unless br
        @lib.logger.warn {"Could not find '#{branch_name}' in #{@items.map{|i|i.name}.join(',')}"}
      end
      br
    end

  end

end
