# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))
  driver :job_control_driver

  context "rjn0001" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      @jobnet = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @jobnet.id,
        })
    end

    it "ジョブの起動イベントを受け取ったら" do
      @jobnet.phase_key = :starting
      @ctx.edge(:e1).status_key = :transmitting
      @ctx.vertex(:j11).phase_key = :ready
      @jobnet.save!
      @jobnet.reload
      tengine.should_not_fire
      mock_ssh = mock(:ssh)
      mock_channel = mock(:channel)
      Net::SSH.should_receive(:start).
        with("184.72.20.1", "goku", :password => "dragonball").and_yield(mock_ssh)
      mock_ssh.should_receive(:open_channel).and_yield(mock_channel)
      mock_channel.should_receive(:exec) do |*args|
        args.length.should == 1
        # args.first.should =~ %r<source \/etc\/profile && export MM_ACTUAL_JOB_ID=[0-9a-f]{24} MM_ACTUAL_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" MM_FULL_ACTUAL_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" MM_ACTUAL_JOB_NAME_PATH=\\"/rjn0001/j11\\" MM_ACTUAL_JOB_SECURITY_TOKEN= MM_SCHEDULE_ID=[0-9a-f]{24} MM_SCHEDULE_ESTIMATED_TIME= MM_TEMPLATE_JOB_ID=[0-9a-f]{24} MM_TEMPLATE_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" && tengine_job_agent_run -- \$HOME/j11\.sh>
        args.first.should =~ %r<source \/etc\/profile>
        args.first.should =~ %r<MM_ACTUAL_JOB_ID=[0-9a-f]{24} MM_ACTUAL_JOB_ANCESTOR_IDS=\"[0-9a-f]{24}\" MM_FULL_ACTUAL_JOB_ANCESTOR_IDS=\"[0-9a-f]{24}\" MM_ACTUAL_JOB_NAME_PATH=\"/rjn0001/j11\" MM_ACTUAL_JOB_SECURITY_TOKEN= MM_SCHEDULE_ID=[0-9a-f]{24} MM_SCHEDULE_ESTIMATED_TIME= MM_TEMPLATE_JOB_ID=[0-9a-f]{24} MM_TEMPLATE_JOB_ANCESTOR_IDS=\"[0-9a-f]{24}\">
        args.first.should =~ %r<job_test j11>
      end
      tengine.receive("start.job.job.tengine", :properties => {
          :execution_id => @execution.id.to_s,
          :root_jobnet_id => @jobnet.id.to_s,
          :target_jobnet_id => @jobnet.id.to_s,
          :target_job_id => @ctx.vertex(:j11).id.to_s,
        })
      @jobnet.reload
      @ctx.edge(:e1).status_key.should == :transmitted
      @ctx.edge(:e2).status_key.should == :active
      @ctx.vertex(:j11).phase_key.should == :starting
    end

    it "PIDを取得できたら" do
      @ctx.edge(:e1).status_key = :transmitted
      @ctx.edge(:e2).status_key = :active
      @ctx.vertex(:j11).phase_key = :starting
      @jobnet.save!
      @jobnet.reload
      tengine.should_not_fire
      mock_event = mock(:event)
      @pid = "123"
      signal = Tengine::Job::Signal.new(mock_event)
      signal.data = {:executing_pid => @pid}
      @ctx.vertex(:j11).ack(signal) # このメソッド内ではsaveされないので、ここでreloadもしません。
      @ctx.vertex(:j11).executing_pid.should == @pid
      @ctx.edge(:e1).status_key.should == :transmitted
      @ctx.edge(:e2).status_key.should == :active
      @ctx.vertex(:j11).phase_key.should == :running
    end

    {
      :success => "0",
      :error => "1"
    }.each do |phase_key, exit_status|
      it "ジョブ実行#{phase_key}の通知" do
        @jobnet.reload
        j11 = @jobnet.find_descendant_by_name_path("/rjn0001/j11")
        j11.executing_pid = "123"
        j11.phase_key = :running
        j11.previous_edges.length.should == 1
        j11.previous_edges.first.status_key = :transmitted
        @ctx[:root].save!
        tengine.should_fire(:"#{phase_key}.job.job.tengine",
          :source_name => @ctx[:j11].name_as_resource,
          :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @jobnet.id.to_s,
            :target_jobnet_id => @jobnet.id.to_s,
            :target_job_id => @ctx[:j11].id.to_s,
            :exit_status => exit_status
          })
        tengine.receive(:"finished.process.job.tengine",
          :source_name => @ctx[:j11].name_as_resource,
          :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @jobnet.id.to_s,
            :target_jobnet_id => @jobnet.id.to_s,
            :target_job_id => @ctx[:j11].id.to_s,
            :exit_status => exit_status
          })
        @jobnet.reload
        @ctx.edge(:e1).status_key.should == :transmitted
        @ctx.edge(:e2).status_key.should == :active
        @ctx.vertex(:j11).tap do |j|
          j.phase_key.should == phase_key
          j.exit_status.should == exit_status
        end
      end
    end

    it "強制停止" do
      @pid = "123"
      @jobnet.reload
      j11 = @jobnet.find_descendant_by_name_path("/rjn0001/j11")
      j11.executing_pid = @pid
      j11.phase_key = :running
      j11.previous_edges.length.should == 1
      j11.previous_edges.first.status_key = :transmitted
      @ctx[:root].save!

      tengine.should_not_fire
      mock_ssh = mock(:ssh)
      mock_channel = mock(:channel)
      Net::SSH.should_receive(:start).
        with("184.72.20.1", "goku", :password => "dragonball").and_yield(mock_ssh)
      mock_ssh.should_receive(:open_channel).and_yield(mock_channel)
      mock_channel.should_receive(:exec) do |*args|
        interval = Tengine::Job::Killing::DEFAULT_KILLING_SIGNAL_INTERVAL
        args.length.should == 1
        args.first.should =~ %r<source \/etc\/profile>
        args.first.should =~ %r<tengine_job_agent_kill #{@pid} #{interval} KILL$>
      end
      tengine.receive(:"stop.job.job.tengine",
        :source_name => @ctx[:j11].name_as_resource,
        :properties => {
          :execution_id => @execution.id.to_s,
          :root_jobnet_id => @jobnet.id.to_s,
          :target_jobnet_id => @jobnet.id.to_s,
          :target_job_id => @ctx[:j11].id.to_s,
        })
      @jobnet.reload
      @ctx.edge(:e1).status_key.should == :transmitted
      @ctx.edge(:e2).status_key.should == :active
      @ctx.vertex(:j11).tap do |j|
        j.phase_key.should == :dying
        j.exit_status.should == nil
      end
    end


    if ENV['PASSWORD']
    context "実際にSSHで接続", :ssh_actual => true do
      before do
        resource_fixture = GokuAtEc2ApNortheast.new
        credential = resource_fixture.goku_ssh_pw
        credential.auth_values = {:username => ENV['USER'], :password => ENV['PASSWORD']}
        credential.save!
        server = resource_fixture.hadoop_master_node
        server.local_ipv4 = "127.0.0.1"
        server.save!
      end

      it do
        tengine.should_not_fire
        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @jobnet.id.to_s,
            :target_jobnet_id => @jobnet.id.to_s,
          })
        @jobnet.reload
        j11 = @jobnet.find_descendant_by_name_path("/rjn0001/j11")
        j11.executing_pid.should_not be_nil
        j11.exit_status.should == nil
        j11.phase_key.should == :running
        j11.previous_edges.length.should == 1
        j11.previous_edges.first.status_key.should == :transmitted
      end

    end
    end
  end

end
