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

require 'git-process/git_logger'
include GitProc

describe GitLogger do

  it "should log info blocks" do
    val = false
    GitLogger.new(GitLogger::INFO, nil).info { val = true }
    val.should == true
  end


  it "should not log info blocks by default" do
    val = false
    GitLogger.new(nil, nil).info { val = true }
    val.should == false
  end


  it "should log warn blocks" do
    val = false
    GitLogger.new(GitLogger::WARN, nil).warn { val = true }
    val.should == true
  end


  it "should log warn blocks by default" do
    val = false
    GitLogger.new(nil, nil).warn { val = true }
    val.should == true
  end


  it "should log error blocks" do
    val = false
    GitLogger.new(GitLogger::ERROR, nil).error { val = true }
    val.should == true
  end


  it "should log error blocks by default" do
    val = false
    GitLogger.new.error { val = true }
    val.should == true
  end


  it "should log debug blocks" do
    val = false
    GitLogger.new(GitLogger::DEBUG, nil).debug { val = true }
    val.should == true
  end

end
