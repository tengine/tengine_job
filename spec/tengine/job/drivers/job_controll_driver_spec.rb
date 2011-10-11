# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))
  driver :job_control_driver

  context "rjn0001" do
    before do
      builder = Rjn0001SimpleJobnetBuilder.new
      @jobnet = builder.create_actual
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @jobnet.id,
        })
    end

    it "最初のリクエスト" do
      tengine.should_not_fire
      mock_ssh = mock(:ssh)
      mock_channel = mock(:channel)
      Net::SSH.should_receive(:start).
        with("184.72.20.1", "goku", :password => "dragonball").twice.and_yield(mock_ssh)
      mock_ssh.should_receive(:open_channel).twice.and_yield(mock_channel)
      mock_channel.should_receive(:exec!).twice do |*args|
        args.length.should == 1
        # args.first.should =~ %r<source \/etc\/profile && export MM_ACTUAL_JOB_ID=[0-9a-f]{24} MM_ACTUAL_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" MM_FULL_ACTUAL_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" MM_ACTUAL_JOB_NAME_PATH=\\"/rjn0001/j11\\" MM_ACTUAL_JOB_SECURITY_TOKEN= MM_SCHEDULE_ID=[0-9a-f]{24} MM_SCHEDULE_ESTIMATED_TIME= MM_TEMPLATE_JOB_ID=[0-9a-f]{24} MM_TEMPLATE_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" && tengine_job_agent_run -- \$HOME/j11\.sh>
        args.first.should =~ %r<source \/etc\/profile>
        args.first.should =~ %r<MM_ACTUAL_JOB_ID=[0-9a-f]{24} MM_ACTUAL_JOB_ANCESTOR_IDS=\"[0-9a-f]{24}\" MM_FULL_ACTUAL_JOB_ANCESTOR_IDS=\"[0-9a-f]{24}\" MM_ACTUAL_JOB_NAME_PATH=\"/rjn0001/j11\" MM_ACTUAL_JOB_SECURITY_TOKEN= MM_SCHEDULE_ID=[0-9a-f]{24} MM_SCHEDULE_ESTIMATED_TIME= MM_TEMPLATE_JOB_ID=[0-9a-f]{24} MM_TEMPLATE_JOB_ANCESTOR_IDS=\"[0-9a-f]{24}\">
        args.first.should =~ %r<\$HOME\/j11\.sh>
      end
      tengine.receive("start.job.tengine", :properties => {
          :execution_id => @execution.id.to_s,
          :root_jobnet_id => @jobnet.id.to_s,
          :target_jobnet_id => @jobnet.id.to_s,
        })
    end
  end

end
