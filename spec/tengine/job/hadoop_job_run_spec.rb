# -*- coding: utf-8 -*-
require 'spec_helper'

describe 'hadoop_job_run' do

  context "rjn1004" do
    before(:all) do
      Tengine::Job::Vertex.delete_all
      builder = Rjn1004HadoopJobInJobnetFixture.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
    end

    Tengine::Job::JobnetActual.phase_keys.each do |phase_key|
      context "hadoop_job_run1のphase_keyを#{phase_key}に設定する" do
        before(:all) do
          @ctx[:hadoop_job_run1].phase_key = phase_key
          @root.save!
        end

        %w[
           /rjn1004/hadoop_job_run1/hadoop_job1
           /rjn1004/hadoop_job_run1/hadoop_job1/Map
           /rjn1004/hadoop_job_run1/hadoop_job1/Reduce
           /rjn1004/hadoop_job_run1/hadoop_job2
           /rjn1004/hadoop_job_run1/hadoop_job2/Map
           /rjn1004/hadoop_job_run1/hadoop_job2/Reduce
        ].each do |name_path|
          it "その子どものhadoop_job, Map, Reduceのphase_keyも#{phase_key}になる" do
            @root.vertex_by_name_path(name_path).phase_key.should == phase_key
          end
        end
      end
    end

  end

end
