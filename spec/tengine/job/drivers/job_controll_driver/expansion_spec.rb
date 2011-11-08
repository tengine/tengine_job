# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))
  driver :job_control_driver

  # in [rjn0008]
  # (S1) --e1-->(rjn0001)--e2-->(rjn0002)--e3-->(E1)
  #
  # in [rjn0001]
  # (S1) --e1-->(j11)--e2-->(j12)--e3-->(E1)
  #
  # in [rjn0002]
  #              |--e2-->(j11)--e4-->|
  # (S1)--e1-->[F1]                [J1]--e6-->(E1)
  #              |--e3-->(j12)--e5-->|
  context "rjn0008" do
    before do
      Tengine::Job::Vertex.delete_all
      Rjn0001SimpleJobnetBuilder.new.create_template
      Rjn0002SimpleParallelJobnetBuilder.new.create_template
      builder = Rjn0008ExpansionFixture.new
      @template = builder.create_template
      @root = @template.generate
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

    context "/rjn0008/rjn0001/j11を実行する際の環境変数" do
      it "expansionだったジョブネットよりも上位のジョブの情報は出力されない" do
        @rjn0001 = @root.vertex_by_name_path("/rjn0008/rjn0001")
        @j11 = @root.vertex_by_name_path("/rjn0008/rjn0001/j11")
        @root.phase_key = :running
        @rjn0001.phase_key = :running
        @j11.phase_key = :ready
        @j11.prev_edges.each{|edge| edge.status_key = :transmitting}
        @root.save!
        @root.reload
        tengine.should_not_fire
        mock_ssh = mock(:ssh)
        mock_channel = mock(:channel)
        Net::SSH.should_receive(:start).
          with("localhost", "goku", :password => "dragonball").and_yield(mock_ssh)
        mock_ssh.should_receive(:open_channel).and_yield(mock_channel)
        mock_channel.should_receive(:exec) do |*args|
          args.length.should == 1
          # args.first.should =~ %r<source \/etc\/profile && export MM_ACTUAL_JOB_ID=[0-9a-f]{24} MM_ACTUAL_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" MM_FULL_ACTUAL_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" MM_ACTUAL_JOB_NAME_PATH=\\"/rjn0001/j11\\" MM_ACTUAL_JOB_SECURITY_TOKEN= MM_SCHEDULE_ID=[0-9a-f]{24} MM_SCHEDULE_ESTIMATED_TIME= MM_TEMPLATE_JOB_ID=[0-9a-f]{24} MM_TEMPLATE_JOB_ANCESTOR_IDS=\\"[0-9a-f]{24}\\" && tengine_job_agent_run -- \$HOME/j11\.sh>
          args.first.should =~ %r<source \/etc\/profile>
          t_rjn1001 = Tengine::Job::RootJobnetTemplate.by_name("rjn0001")
          t_j11 = t_rjn1001.vertex_by_name_path("/rjn0001/j11")
          args.first.should =~ %r<MM_TEMPLATE_JOB_ID=#{t_j11.id.to_s}>
          args.first.should_not =~ %r<MM_TEMPLATE_JOB_ANCESTOR_IDS=\"#{@template.id.to_s};#{t_rjn1001.id.to_s}\">
          args.first.should =~ %r<MM_TEMPLATE_JOB_ANCESTOR_IDS=\"#{t_rjn1001.id.to_s}\">
          args.first.should =~ %r<job_test j11>
        end
        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :target_jobnet_id => @rjn0001.id.to_s,
            :target_job_id => @j11.id.to_s,
          })
        @root.reload
        @rjn0001 = @root.vertex_by_name_path("/rjn0008/rjn0001")
        @j11 = @root.vertex_by_name_path("/rjn0008/rjn0001/j11")
        @root.phase_key = :running
        @rjn0001.phase_key = :running
      end

    end
  end

end


