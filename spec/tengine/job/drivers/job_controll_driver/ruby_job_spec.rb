# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))
  driver :job_control_driver


  context "rjn0022" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0022RubyJobFixture.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
    end

    context "ジョブの起動イベントを受け取ったら" do
      it "通常の場合" do
        @root.phase_key = :starting
        @ctx.edge(:e1).phase_key = :transmitting
        @ctx.vertex(:j1).phase_key = :ready
        @root.save!
        @root.reload

        STDOUT.should_receive(:puts).with("j1") do
          @root.reload
          @ctx.edge(:e1).phase_key.should == :transmitted
          @ctx.edge(:e2).phase_key.should == :active
          @ctx.vertex(:j1).phase_key.should == :running
        end

        tengine.should_fire(:"success.job.job.tengine", {
            :source_name => @ctx.vertex(:j1).name_as_resource,
            :properties=>{
              :execution_id => @execution.id.to_s,
              :root_jobnet_id => @root.id.to_s,
              :root_jobnet_name_path => @root.name_path,
              :target_jobnet_id => @root.id.to_s,
              :target_jobnet_name_path => @root.name_path,
              :target_job_id => @ctx.vertex(:j1).id.to_s,
              :target_job_name_path => @ctx.vertex(:j1).name_path,
            }
          })

        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j1).id.to_s,
            :target_job_name_path => @ctx.vertex(:j1).name_path,
          })
        @root.reload
        @ctx.edge(:e1).phase_key.should == :transmitted
        @ctx.edge(:e2).phase_key.should == :active
        @ctx.vertex(:j1).phase_key.should == :success
      end

      it "ブロックの中で例外がraiseされた場合" do
        @root.phase_key = :starting
        @ctx.edge(:e1).phase_key = :transmitting
        @ctx.vertex(:j1).phase_key = :ready
        @root.save!
        @root.reload

        STDOUT.should_receive(:puts).with("j1").and_raise(Errno::ENOMEM.new("Not enough space."))

        @__kernel__.should_receive(:fire).with(:"error.job.job.tengine", an_instance_of(Hash)) do |_, hash|
          hash[:source_name].should == @ctx[:j1].name_as_resource
          hash[:properties].delete(:message).should =~ /^\[Errno::ENOMEM\] Cannot allocate memory - Not enough space\./
          hash[:properties].should == {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j1).id.to_s,
            :target_job_name_path => @ctx.vertex(:j1).name_path,
          }
        end

        tengine.receive("start.job.job.tengine", :properties => {
            :execution_id => @execution.id.to_s,
            :root_jobnet_id => @root.id.to_s,
            :root_jobnet_name_path => @root.name_path,
            :target_jobnet_id => @root.id.to_s,
            :target_jobnet_name_path => @root.name_path,
            :target_job_id => @ctx.vertex(:j1).id.to_s,
            :target_job_name_path => @ctx.vertex(:j1).name_path,
          })
        @root.reload
        @ctx.edge(:e1).phase_key.should == :transmitted
        @ctx.edge(:e2).phase_key.should == :active
        @ctx.vertex(:j1).phase_key.should == :error
      end
    end

  end

end


