# -*- coding: utf-8 -*-
require 'spec_helper'

describe "reset" do
  before do
    @record = eval(File.read(File.expand_path("reset_spec/4056_1_dump.txt", File.dirname(__FILE__))))
    Tengine::Job::Vertex.collection.insert(@record)
    @root = Tengine::Job::Vertex.find(@record["_id"])
  end

  it do
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
    #
    @execution.stub(:target_actuals).and_return([@jn11])


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

    @root.update_with_lock do
      @execution.transmit(@signal)
    end
    # @execution.should_receive(:activate)
    #
    @root.reload

    @root.element('/jn0006/jn1'             ).phase_key.should == :error
    @root.element('/jn0006/jn1/jn11'        ).phase_key.should == :ready
    @root.element('/jn0006/jn1/jn11/finally').phase_key.should == :initialized
    # @root.element('/jn0006/jn1/finally'     ).phase_key.should == :initialized
    @root.element('/jn0006/jn2'             ).phase_key.should == :initialized
    @root.element('/jn0006/jn2/jn22'        ).phase_key.should == :initialized
    @root.element('/jn0006/jn2/jn22/finally').phase_key.should == :initialized
    @root.element('/jn0006/jn2/finally'     ).phase_key.should == :initialized
    # @root.element('/jn0006/finally'         ).phase_key.should == :initialized

    # @root.edges.map(&:phase_key).should == [:transmitted, :closed, :closed]
    @root.element('/jn0006/jn1'             ).edges.map(&:phase_key).should == [:transmitted, :active, :active]
    @root.element('/jn0006/jn1/jn11'        ).edges.map(&:phase_key).should == [:active, :active, :active]
    @root.element('/jn0006/jn1/jn11/finally').edges.map(&:phase_key).should == [:active, :active]
    # @root.element('/jn0006/jn1/finally'     ).edges.map(&:phase_key).should == [:active, :active]
    @root.element('/jn0006/jn2'             ).edges.map(&:phase_key).should == [:active, :active, :active]
    @root.element('/jn0006/jn2/jn22'        ).edges.map(&:phase_key).should == [:active, :active, :active]
    @root.element('/jn0006/jn2/jn22/finally').edges.map(&:phase_key).should == [:active, :active]
    @root.element('/jn0006/jn2/finally'     ).edges.map(&:phase_key).should == [:active, :active]
    @root.element('/jn0006/finally'         ).edges.map(&:phase_key).should == [:transmitted, :transmitted]

    @root.element('/jn0006/finally'         ).phase_key.should == :initialized
    @root.element('/jn0006/jn1/finally'     ).phase_key.should == :initialized
    @root.element('/jn0006/jn1/finally'     ).edges.map(&:phase_key).should == [:active, :active]
    @root.edges.map(&:phase_key).should == [:transmitted, :active, :active]
  end

end
