# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_execution_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../lib/tengine/job/drivers/job_execution_driver.rb", File.dirname(__FILE__))
  driver :job_execution_driver

  # in [rjn0001]
  # (S1) --e1-->(j11)--e2-->(j12)--e3-->(E1)
  context "rjn0001" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
    end

    it "ジョブの起動イベントを受け取ったら" do
      @execution.phase_key = :initialized
      @execution.save!
      @root.phase_key = :initialized
      @root.save!
      tengine.should_fire(:"start.jobnet.job.tengine",
        :source_name => @root.name_as_resource,
        :properties => {
          :execution_id => @execution.id.to_s,
          :root_jobnet_id => @root.id.to_s,
          :target_jobnet_id => @root.id.to_s
        })
      tengine.receive("start.execution.job.tengine", :properties => {
          :execution_id => @execution.id.to_s,
          :root_jobnet_id => @root.id.to_s,
          :target_jobnet_id => @root.id.to_s,
        })
      @execution.reload
      @execution.phase_key.should == :starting
      @root.reload
      @root.phase_key.should == :ready
    end

    # jobnet_control_driverでexecution起動後の処理を行っています
  end

end
