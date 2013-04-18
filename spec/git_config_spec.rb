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

require 'FileHelpers'
require 'git-process/git_lib'
require 'git-process/git_config'
include GitProc

describe GitConfig do

  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  it 'should retrieve values by []' do
    lib = GitLib.new(tmpdir, :log_level => Logger::ERROR)
    lib.command(:config, %w(somevalue.subvalue here))
    config = GitConfig.new(lib)
    config['somevalue.subvalue'].should == 'here'
  end


  it "should set values by []" do
    lib = GitLib.new(tmpdir, :log_level => Logger::ERROR)
    config = GitConfig.new(lib)
    config['somevalue.subvalue'] = 'there'
    lib.command(:config, %w(--get somevalue.subvalue)).should == 'there'
  end

end
