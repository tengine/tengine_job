# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../../lib/tengine/job/drivers/jobnet_control_driver.rb", File.dirname(__FILE__))
  driver :jobnet_control_driver

  # in [j1000]
  # (S1)--e1-->[j1100]--e2-->(j1200)--e3-->[j1300]--e4-->(E1)
  #
  # in [j1100]
  # (S2)--e5-->(j1110)--e6-->[j1120]--e7-->[j1130]--e8-->(j1140)--e9-->(E2)
  #
  # in [j1120]
  # (S3)--e10-->(j1121)--e11-->(E3)
  #
  # in [j1130]
  # (S4)--e12-->(j1131)--e13-->(E4)
  #
  # in [j1300]
  # (S5)--e14-->(j1310)--e15-->(E5)
  #
  context "rjn0006" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0006NestedForkJobnetBuilder.new
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

    it "S1から起動" do
      tengine.should_fire(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
        }))
      tengine.receive("start.jobnet.job.tengine", :properties => @base_props)
      @root.reload
      @ctx.edge(:e1).status_key.should == :transmitted
      (2..15).each do |idx|
        @ctx.edge(:"e#{idx}").status_key.should == :active
      end
      @root.phase_key = :running
      @ctx.vertex(:j1100).phase_key = :starting
    end

    context "j1100を起動" do
      it do
        @root.phase_key = :running
        @ctx.vertex(:j1100).phase_key = :starting
        @ctx[:e1].status_key = :transmitted
        @root.save!
        tengine.should_fire(:"start.job.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
            :target_edge_id => @ctx[:e5].id.to_s,
          }))
        tengine.receive(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
          }))
        @root.reload
        @ctx.edge(:e1).status_key.should == :transmitted
        (2..15).each do |idx|
          @ctx.edge(:"e#{idx}").status_key.should == :active
        end
        @ctx.vertex(:j1100).phase_key.should == :starting
      end
    end

    context 'j1110を実行' do
      it "成功した場合" do
        @root.phase_key = :running
        @ctx.vertex(:j1100).phase_key = :running
        @ctx.vertex(:j1110).phase_key = :success
        @ctx[:e1].status_key = :transmitted
        @ctx[:e5].status_key = :transmitted
        @root.save!
        tengine.should_fire(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1120].id.to_s,
          }))
        tengine.receive("finished.job.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
            :target_job_id => @ctx[:j1110].id.to_s,
          }))
        @root.reload
        @ctx.edge(:e1).status_key.should == :transmitted
        @ctx.edge(:e5).status_key.should == :transmitted
        @ctx.edge(:e6).status_key.should == :transmitted
        ((2..15).to_a - [5, 6]).each do |idx|
          [:"e#{idx}", @ctx.edge(:"e#{idx}").status_key].should == [:"e#{idx}", :active]
        end
        @ctx.vertex(:j1100).phase_key.should == :running
        @ctx.vertex(:j1110).phase_key.should == :success
      end

      it "失敗した場合" do
        @root.phase_key = :running
        @ctx.vertex(:j1100).phase_key = :running
        @ctx.vertex(:j1110).phase_key = :error
        @ctx[:e1].status_key = :transmitted
        @ctx[:e5].status_key = :transmitted
        @root.save!
        tengine.should_fire(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
          }))
        tengine.receive("finished.job.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
            :target_job_id => @ctx[:j1110].id.to_s,
          }))
        @root.reload
        @ctx.edge(:e1).status_key.should == :transmitted
        @ctx.edge(:e5).status_key.should == :transmitted
        (2..4).to_a.each do |idx|
          [:"e#{idx}", @ctx.edge(:"e#{idx}").status_key].should == [:"e#{idx}", :active]
        end
        (6..9).to_a.each do |idx|
          [:"e#{idx}", @ctx.edge(:"e#{idx}").status_key].should == [:"e#{idx}", :closed]
        end
        @ctx.vertex(:j1100).phase_key.should == :error
        @ctx.vertex(:j1110).phase_key.should == :error
      end
    end


    context 'j1100' do
      it "成功した場合" do
        @root.phase_key = :running
        [:j1100, :j1110, :j1120, :j1130, :j1140].each do |jobnet_name|
          @root.vertex(@ctx[jobnet_name].id).phase_key = :success
        end
        @ctx[:e1].status_key = :transmitted
        (5..9).each{|idx|@ctx[:"e#{idx}"].status_key = :transmitted}
        @root.save!
        tengine.should_fire(:"start.job.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @root.id.to_s,
            :target_edge_id => @ctx[:e2].id.to_s,
          }))
        tengine.receive("finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
          }))
        @root.reload
        @root.edge(@ctx[:e1].id).status_key.should == :transmitted
        (2..4).each do |idx|
          [:"e#{idx}", @root.edge(@ctx[:"e#{idx}"].id).status_key].should == [:"e#{idx}", :active]
        end
        (5..9).each do |idx|
          [:"e#{idx}", @root.edge(@ctx[:"e#{idx}"].id).status_key].should == [:"e#{idx}", :transmitted]
        end
        @root.vertex(@ctx[:j1100].id).phase_key.should == :success
        @root.vertex(@ctx[:j1110].id).phase_key.should == :success
      end

      it "失敗した場合" do
        @root.phase_key = :running
        [:j1100, :j1110].each do |jobnet_name|
          @root.vertex(@ctx[jobnet_name].id).phase_key = :error
        end
        [:j1120, :j1130, :j1140].each do |jobnet_name|
          @root.vertex(@ctx[jobnet_name].id).phase_key = :ready
        end
        @ctx[:e1].status_key = :transmitted
        @ctx[:e5].status_key = :transmitted
        (6..9).each{|idx|@ctx[:"e#{idx}"].status_key = :closed}
        @root.save!

        tengine.should_fire(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @root.id.to_s,
          }))
        tengine.receive("finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
          }))
        @root.reload
        @root.edge(@ctx[:e1].id).status_key.should == :transmitted
        (2..4).each do |idx|
          [:"e#{idx}", @root.edge(@ctx[:"e#{idx}"].id).status_key].should == [:"e#{idx}", :closed]
        end
        @root.edge(@ctx[:e5].id).status_key.should == :transmitted
        (6..9).each do |idx|
          [:"e#{idx}", @root.edge(@ctx[:"e#{idx}"].id).status_key].should == [:"e#{idx}", :closed]
        end
        @root.vertex(@ctx[:j1100].id).phase_key.should == :error
        @root.vertex(@ctx[:j1110].id).phase_key.should == :error
      end
    end

  end

end
