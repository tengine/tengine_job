# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::JobnetActual do

  describe "reset rjn0010" do
    # in [rjn0010]
    #              |-----e2----->(j11)-----e4----->|
    # [S1]--e1-->[F1]                            [J1]--e7-->[E1]
    #              |--e3-->(j12)--e5-->(j13)--e6-->|
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn00102jobsAnd1jobParallelJobnetBuilder.new
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
      mock_event = mock(:event)
      mock_event.stub(:[]).with(:execution_id).and_return(@execution.id.to_s)
      @signal = Tengine::Job::Signal.new(mock_event)
    end

    shared_examples_for "全て再実行するためにrootをリセット" do
      it "全てのedgeとvetexは初期化される" do
        @root.reset(@signal)
        @root.save!
        @root.reload
        [:root, :j11, :j12, :j13].each{|j| [j, @ctx[j].phase_key].should == [j, :initialized]}
        @root.edges.each{|edge| edge.phase_key.should == :active }
      end
    end

    context "全て正常終了した後に" do
      before do
        [:root, :j11, :j12, :j13].each{|j| @ctx[j].phase_key = :success}
        @root.edges.each{|edge| edge.phase_key = :transmitted }
        @root.save!
      end

      it_should_behave_like "全て再実行するためにrootをリセット"

      it "一部再実行の為にreset" do
        @ctx[:j12].reset(@signal)
        @root.save!
        @root.reload
        [:root, :j11].each{|j| @ctx[j].phase_key.should == :success}
        [:j12, :j13].each{|j| @ctx[j].phase_key.should == :initialized}
        [:e1, :e2, :e3, :e4].each{|n| @ctx[n].phase_key.should == :transmitted }
        [:e5, :e6, :e7].each{|n| @ctx[n].phase_key.should == :active }
      end
    end

    context "異常終了した後に" do
      before do
        [:root, :j12].each{|j| @ctx[j].phase_key = :error}
        [:j11].each{|j| @ctx[j].phase_key = :success}
        [:j13].each{|j| @ctx[j].phase_key = :initialized}
        [:e1, :e2, :e3, :e4].each{|n| @ctx[n].phase_key = :transmitted }
        [:e5, :e6, :e7].each{|n| @ctx[n].phase_key = :active }
        @root.save!
      end

      it_should_behave_like "全て再実行するためにrootをリセット"

      it "j11をreset" do
        @ctx[:j11].reset(@signal)
        @root.save!
        @root.reload
        [:root, :j12].each{|j| [j, @ctx[j].phase_key].should == [j, :error]}
        [:j11, :j13].each{|j| @ctx[j].phase_key.should == :initialized}
        [:e1, :e2, :e3].each{|n| @ctx[n].phase_key.should == :transmitted }
        [:e4, :e5, :e6, :e7].each{|n| @ctx[n].phase_key.should == :active }
      end

      it "j12をreset" do
        @ctx[:j12].reset(@signal)
        @root.save!
        @root.reload
        [:root, ].each{|j| [j, @ctx[j].phase_key].should == [j, :error]}
        [:j11, ].each{|j| @ctx[j].phase_key.should == :success}
        [:j12, :j13].each{|j| @ctx[j].phase_key.should == :initialized}
        [:e1, :e2, :e3, :e4].each{|n| @ctx[n].phase_key.should == :transmitted }
        [:e5, :e6, :e7].each{|n| @ctx[n].phase_key.should == :active }
      end

      it "j13をreset" do
        @ctx[:j13].reset(@signal)
        @root.save!
        @root.reload
        [:root, :j12, ].each{|j| [j, @ctx[j].phase_key].should == [j, :error]}
        [:j11, ].each{|j| @ctx[j].phase_key.should == :success}
        [:j13].each{|j| @ctx[j].phase_key.should == :initialized}
        [:e1, :e2, :e3, :e4].each{|n| @ctx[n].phase_key.should == :transmitted }
        [:e5, :e6, :e7].each{|n| @ctx[n].phase_key.should == :active }
      end
    end


  end
end
