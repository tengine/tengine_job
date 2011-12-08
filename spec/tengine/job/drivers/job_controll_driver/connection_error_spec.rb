# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'connection error' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))
  driver :job_control_driver

  # in [rjn0001]
  # (S1) --e1-->(j11)--e2-->(j12)--e3-->(E1)
  #
  context "rjn0001" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @base_props = {
        :execution_id => @execution.id.to_s,
        :root_jobnet_id => @root.id.to_s,
        :target_jobnet_id => @root.id.to_s,
      }
    end

    after do
      # 中身を書き換えてしまうので他のテストに影響しないように削除します
      Tengine::Resource::Credential.delete_all
      Tengine::Resource::Server.delete_all
    end

    context "credential not found" do
      it "対象のジョブはerrorになりエラーイベントが発火される" do
        Tengine::Resource::Credential.delete_all
        @root.phase_key = :starting
        @ctx.edge(:e1).phase_key = :transmitting
        @ctx.vertex(:j11).phase_key = :ready
        @root.save!
        @root.reload
        tengine.should_fire(:"error.job.job.tengine", an_instance_of(Hash))
        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j11).id.to_s,
            :target_job_name_path => @ctx.vertex(:j11).name_path,
          })
        @root.reload
        @ctx.edge(:e1).phase_key.should == :transmitted
        @ctx.edge(:e2).phase_key.should == :active
        @ctx.vertex(:j11).phase_key.should == :error
      end
    end


    context "wrong credential" do
      it "対象のジョブはerrorになりエラーイベントが発火される" do
        credential = Tengine::Resource::Credential.find_by_name("test_credential1")
        hash = credential.auth_values.dup
        hash['username'] = "piccolo"
        credential.auth_values = hash
        credential.save!
        @root.phase_key = :starting
        @ctx.edge(:e1).phase_key = :transmitting
        @ctx.vertex(:j11).phase_key = :ready
        @root.save!
        @root.reload
        tengine.should_fire(:"error.job.job.tengine", an_instance_of(Hash))
        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j11).id.to_s,
            :target_job_name_path => @ctx.vertex(:j11).name_path,
          })
        @root.reload
        @ctx.edge(:e1).phase_key.should == :transmitted
        @ctx.edge(:e2).phase_key.should == :active
        @ctx.vertex(:j11).phase_key.should == :error
      end
    end

    context "server not found" do
      it "対象のジョブはerrorになりエラーイベントが発火される" do
        Tengine::Resource::Server.delete_all
        @root.phase_key = :starting
        @ctx.edge(:e1).phase_key = :transmitting
        @ctx.vertex(:j11).phase_key = :ready
        @root.save!
        @root.reload
        tengine.should_fire(:"error.job.job.tengine", an_instance_of(Hash))
        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j11).id.to_s,
            :target_job_name_path => @ctx.vertex(:j11).name_path,
          })
        @root.reload
        @ctx.edge(:e1).phase_key.should == :transmitted
        @ctx.edge(:e2).phase_key.should == :active
        @ctx.vertex(:j11).phase_key.should == :error
      end
    end


    context "wrong server IP" do
      it "対象のジョブはerrorになりエラーイベントが発火される" do
        server = Tengine::Resource::Server.find_by_name("test_server1")
        server.addresses = {'private_ip_address' => "unexist_ip"}
        server.save!
        @root.phase_key = :starting
        @ctx.edge(:e1).phase_key = :transmitting
        @ctx.vertex(:j11).phase_key = :ready
        @root.save!
        @root.reload
        tengine.should_fire(:"error.job.job.tengine", an_instance_of(Hash))
        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j11).id.to_s,
            :target_job_name_path => @ctx.vertex(:j11).name_path,
          })
        @root.reload
        @ctx.edge(:e1).phase_key.should == :transmitted
        @ctx.edge(:e2).phase_key.should == :active
        @ctx.vertex(:j11).phase_key.should == :error
      end
    end


  end

end


