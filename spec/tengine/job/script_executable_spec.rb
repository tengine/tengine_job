# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::ScriptExecutable do
  describe :execute do
    context "実際にSSHで接続", :ssh_actual => true do
      before do
        @credential = Tengine::Resource::Credential.find_or_create_by(
          :name => "goku",
          :auth_type_key => :ssh_password,
          :auth_values => {:username => 'goku', :password => "dragonball"})
        @server = Tengine::Resource::VirtualServer.find_or_create_by(
          :name => "local_dev",
          :provided_name => "cloud-dev-mini",
          :status => "running",
          :local_ipv4 => "192.168.1.90")
      end

#       it "終了コードを取得できる" do
#         Tengine::Job::ScriptActual.new(:name => "echo_foo",
#           :script => "/Users/goku/tengine/echo_foo.sh"
#           )
#       end

    end
  end
end
