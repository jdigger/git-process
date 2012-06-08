require File.expand_path('../../../lib/git-lib', __FILE__)
require File.expand_path('../../FileHelpers', __FILE__)

describe Git::GitLib do

  describe "status" do

    before(:each) do
      @tmpdir = Dir.mktmpdir
      @gl = Git::GitLib.new(@tmpdir, :log_level => Logger::ERROR)
      create_files(['.gitignore'])
      @gl.commit('initial')
    end


    after(:each) do
      rm_rf(@tmpdir)
    end


    def create_files(file_names)
      Dir.chdir(@gl.workdir) do |dir|
        file_names.each do |fn|
          @gl.logger.debug {"Creating #{dir}/#{fn}"}
          FileUtils.touch fn
        end
      end
      @gl.add(file_names)
    end


    it "should handle added files" do
      create_files(['a', 'b', 'c'])

      @gl.status.added.should == ['a', 'b', 'c']
    end


    it "should handle a modification on both sides" do
      change_file_and_commit('a', '')

      @gl.checkout('master', :new_branch => 'fb')
      change_file_and_commit('a', 'hello')

      @gl.checkout('master')
      change_file_and_commit('a', 'goodbye')

      @gl.merge('fb') rescue

      status = @gl.status
      status.unmerged.should == ['a']
      status.modified.should == ['a']
    end


    it "should handle an addition on both sides" do
      @gl.checkout('master', :new_branch => 'fb')
      change_file_and_commit('a', 'hello')

      @gl.checkout('master')
      change_file_and_commit('a', 'goodbye')

      @gl.merge('fb') rescue

      status = @gl.status
      status.unmerged.should == ['a']
      status.added.should == ['a']
    end


    it "should handle a merge deletion on fb" do
      change_file_and_commit('a', '')

      @gl.checkout('master', :new_branch => 'fb')
      @gl.remove('a', :force => true)
      @gl.commit('removed a')

      @gl.checkout('master')
      change_file_and_commit('a', 'goodbye')

      @gl.merge('fb') rescue

      status = @gl.status
      status.unmerged.should == ['a']
      status.deleted.should == ['a']
    end


    it "should handle a merge deletion on master" do
      change_file_and_commit('a', '')

      @gl.checkout('master', :new_branch => 'fb')
      change_file_and_commit('a', 'hello')

      @gl.checkout('master')
      @gl.remove('a', :force => true)
      @gl.commit('removed a')

      @gl.merge('fb') rescue

      status = @gl.status
      status.unmerged.should == ['a']
      status.deleted.should == ['a']
    end


    def change_file_and_commit(filename, contents)
      Dir.chdir(@gl.workdir) do
        File.open(filename, 'w') {|f| f.puts contents}
      end
      @gl.add(filename)
      @gl.commit("#{filename} - #{contents}")
    end


    it "should return an empty result" do
      @gl.status.added.should == []
      @gl.status.deleted.should == []
      @gl.status.modified.should == []
      @gl.status.unmerged.should == []
    end

  end

end
