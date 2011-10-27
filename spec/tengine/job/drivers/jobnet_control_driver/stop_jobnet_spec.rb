# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'stop.jobnet.job.tengine' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../../lib/tengine/job/drivers/jobnet_control_driver.rb", File.dirname(__FILE__))
  driver :jobnet_control_driver

  context "rjn0006" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0006NestedForkJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
    end

    context "j1120" do
      before do
        @ctx[:root].tap{|j| j.phase_key = :running}
        @ctx[:j1100].tap{|j| j.phase_key = :running}
        @ctx[:j1110].tap{|j| j.phase_key = :success; j.executing_pid = "1110"}
        [:e1, :e5, :e6].each{|name| @ctx[name].status_key = :transmitted}
        @base_props = {
          :execution_id => @execution.id.to_s,
          :root_jobnet_id => @root.id.to_s,
          :target_jobnet_id => @ctx[:j1120].id.to_s,
        }
      end

      context "runningの場合" do
        before do
          @ctx[:j1120].tap{|j| j.phase_key = :running}
        end

        context "j1121がinitialized" do
          before do
            @ctx[:j1121].tap{|j| j.phase_key = :initialized}
            [:e10].each{|name| @ctx[name].status_key = :active}
            @root.save!
          end

          it "j1120をstopすると自身をdyingにして、j1121については何もしません" do
            tengine.should_not_fire
            tengine.receive(:"stop.jobnet.job.tengine",
              :source_name => @ctx[:j1120].name_as_resource,
              :properties => @base_props.merge({
                  :target_jobnet_id => @ctx[:j1120].id.to_s,
                }))
            @root.reload
            @root.phase_key.should == :running
            @ctx[:j1100].tap{|j| j.phase_key.should == :running}
            @ctx[:j1110].tap{|j| j.phase_key.should == :success}
            @ctx[:j1120].tap{|j| j.phase_key.should == :dying}
            @ctx[:j1121].tap{|j| j.phase_key.should == :initialized}
            [:e1, :e5, :e6].each{|name| @ctx.edge(name).status_key.should == :transmitted }
            (2..4).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
            (6..15).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
          end
        end

        context "j1121がready" do
          before do
            @ctx[:j1121].tap{|j| j.phase_key = :ready}
            [:e10].each{|name| @ctx[name].status_key = :transmitting}
            @root.save!
          end

          it "j1120をstopすると自身をdyingにして、j1121については何もしません" do
            tengine.should_fire(:"stop.job.job.tengine",
              :source_name => @ctx[:j1121].name_as_resource,
              :properties => @base_props.merge({
                :target_job_id => @ctx[:j1121].id.to_s,
              }))
            tengine.receive(:"stop.jobnet.job.tengine",
              :source_name => @ctx[:j1120].name_as_resource,
              :properties => @base_props.merge({
                  :target_jobnet_id => @ctx[:j1120].id.to_s,
                }))
            @root.reload
            @root.phase_key.should == :running
            @ctx[:j1100].tap{|j| j.phase_key.should == :running}
            @ctx[:j1110].tap{|j| j.phase_key.should == :success}
            @ctx[:j1120].tap{|j| j.phase_key.should == :dying}
            @ctx[:j1121].tap{|j| j.phase_key.should == :ready}
            [:e1, :e5, :e6].each{|name| @ctx.edge(name).status_key.should == :transmitted }
            [:e10].each{|name| @ctx.edge(name).status_key.should == :transmitting }
            (2..4).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
            (6..9).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
            (11..15).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
          end
        end


        context "j1121がrunning" do
          before do
            @ctx[:j1121].tap{|j| j.phase_key = :running; j.executing_pid = "1121"}
            [:e10].each{|name| @ctx[name].status_key = :transmitted}
            @root.save!
          end

          it "j1120をstopすると自身をdyingにして、エッジをcloseして、stop.job.job.tengineを発火します" do
            tengine.should_fire(:"stop.job.job.tengine",
              :source_name => @ctx[:j1121].name_as_resource,
              :properties => @base_props.merge({
                :target_job_id => @ctx[:j1121].id.to_s,
              }))
            tengine.receive(:"stop.jobnet.job.tengine",
              :source_name => @ctx[:j1120].name_as_resource,
              :properties => @base_props.merge({
                  :target_jobnet_id => @ctx[:j1120].id.to_s,
                }))
            @root.reload
            @root.phase_key.should == :running
            @ctx[:j1100].tap{|j| j.phase_key.should == :running}
            @ctx[:j1110].tap{|j| j.phase_key.should == :success}
            @ctx[:j1120].tap{|j| j.phase_key.should == :dying}
            @ctx[:j1120].tap{|j| j.phase_key.should == :dying}
            [:e1, :e5, :e6, :e10].each{|name| @ctx.edge(name).status_key.should == :transmitted }
            (2..4).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
            (6..9).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
            (11..15).each{|idx| @ctx.edge(:"e#{idx}").status_key.should == :active }
          end
        end
      end
    end

  end

end
