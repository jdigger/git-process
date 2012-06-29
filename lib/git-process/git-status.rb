module Git

  #
  # The status of the Git repository.
  #
  # @!attribute [r] unmerged
  #   @return [Enumerable] a sorted list of unmerged files
  # @!attribute [r] modified
  #   @return [Enumerable] a sorted list of modified files
  # @!attribute [r] deleted
  #   @return [Enumerable] a sorted list of deleted files
  # @!attribute [r] added
  #   @return [Enumerable] a sorted list of files that have been added
  # @!attribute [r] unknown
  #   @return [Enumerable] a sorted list of unknown files
  class GitStatus
    attr_reader :unmerged, :modified, :deleted, :added, :unknown

    def initialize(lib)
      unmerged = []
      modified = []
      deleted = []
      added = []
      unknown = []

      stats = lib.porcelain_status.split("\n")

      stats.each do |s|
        stat = s[0..1]
        file = s[3..-1]
        #puts "stat #{stat} - #{file}"
        case stat
        when 'U ', ' U'
          unmerged << file
        when 'UU'
          unmerged << file
          modified << file
        when 'M ', ' M'
          modified << file
        when 'D ', ' D'
          deleted << file
        when 'DU', 'UD'
          deleted << file
          unmerged << file
        when 'A ', ' A'
          added << file
        when 'AA'
          added << file
          unmerged << file
        when '??'
          unknown << file
        else
          raise "Do not know what to do with status #{stat} - #{file}"
        end
      end

      @unmerged = unmerged.sort.uniq.freeze
      @modified = modified.sort.uniq.freeze
      @deleted = deleted.sort.uniq.freeze
      @added = added.sort.uniq.freeze
      @unknown = unknown.sort.uniq.freeze
    end


    # @return [Boolean] are there any changes in the index or working directory?
    def clean?
      @unmerged.empty? and @modified.empty? and @deleted.empty? and @added.empty? and @unknown.empty?
    end

  end

end
