# -*- coding: utf-8 -*-
require 'spec_helper'

describe "reset" do
  context "@4056" do
    before do
      @record = eval(File.read(File.expand_path("reset_spec/4056_1_dump.txt", File.dirname(__FILE__))))
      Tengine::Job::Vertex.delete_all
      Tengine::Job::Vertex.collection.insert(@record)
      @root = Tengine::Job::Vertex.find(@record["_id"])
    end

    it "状況確認" do
      @root.phase_key.should == :error
      @root.element('/jn0006/jn1'             ).phase_key.should == :error
      @root.element('/jn0006/jn1/jn11'        ).phase_key.should == :error
      @root.element('/jn0006/jn1/jn11/finally').phase_key.should == :success
      @root.element('/jn0006/jn1/finally'     ).phase_key.should == :success
      @root.element('/jn0006/jn2'             ).phase_key.should == :initialized
      @root.element('/jn0006/jn2/jn22'        ).phase_key.should == :initialized
      @root.element('/jn0006/jn2/jn22/finally').phase_key.should == :initialized
      @root.element('/jn0006/jn2/finally'     ).phase_key.should == :initialized
      @root.element('/jn0006/finally'         ).phase_key.should == :success

      @root.edges.map(&:phase_key).should == [:transmitted, :closed, :closed]
      @root.element('/jn0006/jn1'             ).edges.map(&:phase_key).should == [:transmitted, :closed, :closed]
      @root.element('/jn0006/jn1/jn11'        ).edges.map(&:phase_key).should == [:transmitted, :closed, :closed]
      @root.element('/jn0006/jn1/jn11/finally').edges.map(&:phase_key).should == [:transmitted, :transmitted]
      @root.element('/jn0006/jn1/finally'     ).edges.map(&:phase_key).should == [:transmitted, :transmitted]
      @root.element('/jn0006/jn2'             ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn2/jn22'        ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn2/jn22/finally').edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/jn2/finally'     ).edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/finally'         ).edges.map(&:phase_key).should == [:transmitted, :transmitted]
    end

    it "jn11をspotで再実行" do
      @now = Time.now.utc
      @event = mock(:event, :occurred_at => @now)
      @signal = Tengine::Job::Signal.new(@event)
      @jn11 = @root.element("jn11@jn1")
      @execution = Tengine::Job::Execution.create!({
          :target_actual_ids => [@jn11.id.to_s],
          :retry => true, :spot => true,
          :root_jobnet_id => @root.id
        })
      @execution.phase_key.should == :initialized
      @event.stub(:[]).with(:execution_id).and_return(@execution.id.to_s)
      @execution.stub(:target_actuals).and_return([@jn11])

      @root.update_with_lock do
        @execution.transmit(@signal)
      end

      fire_args = @signal.reservations.first.fire_args
      fire_args.first.should == :"start.jobnet.job.tengine"
      hash = fire_args.last
      hash.delete(:source_name).should_not be_nil
      hash.should == {
        :properties => {
          :target_jobnet_id=>@jn11.id.to_s,
          :target_jobnet_name_path=>"/jn0006/jn1/jn11",
          :execution_id=>@execution.id.to_s,
          :root_jobnet_id=>@root.id.to_s,
          :root_jobnet_name_path=>"/jn0006"
        }
      }

      @root.reload
      @root.element('/jn0006/jn1'             ).phase_key.should == :error
      @root.element('/jn0006/jn1/jn11'        ).phase_key.should == :ready
      @root.element('/jn0006/jn1/jn11/finally').phase_key.should == :initialized
      @root.element('/jn0006/jn1/finally'     ).phase_key.should == :success
      @root.element('/jn0006/jn2'             ).phase_key.should == :initialized
      @root.element('/jn0006/jn2/jn22'        ).phase_key.should == :initialized
      @root.element('/jn0006/jn2/jn22/finally').phase_key.should == :initialized
      @root.element('/jn0006/jn2/finally'     ).phase_key.should == :initialized
      @root.element('/jn0006/finally'         ).phase_key.should == :success

      @root.edges.map(&:phase_key).should == [:transmitted, :closed, :closed]
      @root.element('/jn0006/jn1'             ).edges.map(&:phase_key).should == [:transmitted, :closed, :closed]
      @root.element('/jn0006/jn1/jn11'        ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn1/jn11/finally').edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/jn1/finally'     ).edges.map(&:phase_key).should == [:transmitted, :transmitted]
      @root.element('/jn0006/jn2'             ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn2/jn22'        ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn2/jn22/finally').edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/jn2/finally'     ).edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/finally'         ).edges.map(&:phase_key).should == [:transmitted, :transmitted]
    end

    it "jn11以降を再実行" do
      @now = Time.now.utc
      @event = mock(:event, :occurred_at => @now)
      @signal = Tengine::Job::Signal.new(@event)
      @jn11 = @root.element("jn11@jn1")
      @execution = Tengine::Job::Execution.create!({
          :target_actual_ids => [@jn11.id.to_s],
          :retry => true, :spot => false,
          :root_jobnet_id => @root.id
        })
      @execution.phase_key.should == :initialized
      @event.stub(:[]).with(:execution_id).and_return(@execution.id.to_s)
      @execution.stub(:target_actuals).and_return([@jn11])

      @root.update_with_lock do
        @execution.transmit(@signal)
      end

      fire_args = @signal.reservations.first.fire_args
      fire_args.first.should == :"start.jobnet.job.tengine"
      hash = fire_args.last
      hash.delete(:source_name).should_not be_nil
      hash.should == {
        :properties => {
          :target_jobnet_id=>@jn11.id.to_s,
          :target_jobnet_name_path=>"/jn0006/jn1/jn11",
          :execution_id=>@execution.id.to_s,
          :root_jobnet_id=>@root.id.to_s,
          :root_jobnet_name_path=>"/jn0006"
        }
      }

      @root.reload
      @root.element('/jn0006/jn1'             ).phase_key.should == :error
      @root.element('/jn0006/jn1/jn11'        ).phase_key.should == :ready
      @root.element('/jn0006/jn1/jn11/finally').phase_key.should == :initialized
      @root.element('/jn0006/jn1/finally'     ).phase_key.should == :initialized
      @root.element('/jn0006/jn2'             ).phase_key.should == :initialized
      @root.element('/jn0006/jn2/jn22'        ).phase_key.should == :initialized
      @root.element('/jn0006/jn2/jn22/finally').phase_key.should == :initialized
      @root.element('/jn0006/jn2/finally'     ).phase_key.should == :initialized
      @root.element('/jn0006/finally'         ).phase_key.should == :initialized

      @root.edges.map(&:phase_key).should == [:transmitted, :active, :active]
      @root.element('/jn0006/jn1'             ).edges.map(&:phase_key).should == [:transmitted, :active, :active]
      @root.element('/jn0006/jn1/jn11'        ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn1/jn11/finally').edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/jn1/finally'     ).edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/jn2'             ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn2/jn22'        ).edges.map(&:phase_key).should == [:active, :active, :active]
      @root.element('/jn0006/jn2/jn22/finally').edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/jn2/finally'     ).edges.map(&:phase_key).should == [:active, :active]
      @root.element('/jn0006/finally'         ).edges.map(&:phase_key).should == [:active, :active]
    end
  end

end
