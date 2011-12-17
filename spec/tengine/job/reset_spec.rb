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

  # in [jn0005]
  #                         |--e3-->(j2)--e5--->|
  # (S1)--e1-->(j1)--e2-->[F1]                [J1]-->e7-->(j4)--e8-->(E1)
  #                         |--e4-->[jn4]--e6-->|
  #
  # in [jn0005/jn4]
  #                          |--e11-->(j42)--e13-->|
  # (S2)--e9-->(j41)--e10-->[F2]                  [J2]--e15-->(j44)--e16-->(E2)
  #                          |--e12-->(j43)--e14-->|
  #
  # in [jn0005/jn4/finally]
  # (S3)--e17-->(jn4_f)--e18-->(E3)
  #
  # in [jn0005/finally]
  # (S4)--e19-->[jn0005_fjn]--e20-->(jn0005_f)--e21-->(E4)
  #
  # in [jn0005/finally/jn0005_fjn]
  # (S5)--e22-->(jn0005_f1)--e23-->(jn0005_f1)--e24-->(E5)
  #
  # in [jn0005/finally/jn0005_fjn/finally]
  # (S6)--e25-->(jn0005_fif)--e26-->(E6)
  {
    "@4026" => true,
    "@4034" => false,
  }.each do |scenario_no, spot|
    context "#{scenario_no} スポット実行#{spot}" do
      before do
        Tengine::Job::Vertex.delete_all
        builder = Rjn0005RetryTwoLayerFixture.new
        @root = builder.create_actual
        @ctx = builder.context
      end

      context "/jn0005/j1が:errorになって実行が終了した後" do
        before do
          @ctx[:jn0005].phase_key = :error
          @ctx[:j1].phase_key = :error
          @ctx[:jn0005].finally_vertex do |f|
            f.phase_key = :success
            f.descendants.each{|d| d.phase_key = :success}
          end
          @ctx[:e1].phase_key = :transmitted
          (2..8).each{|idx| @ctx[:"e#{idx}"].phase_key = :closed}
          (22..26).each{|idx| @ctx[:"e#{idx}"].phase_key = :transmitted}
          @root.save!
        end

        it "/jn0005/jn4/j41を再実行できる" do
          execution = Tengine::Job::Execution.create!({
              :retry => true, :spot => spot,
              :root_jobnet_id => @root.id,
              :target_actual_ids => [@ctx[:j41].id.to_s]
            })
          execution.stub(:root_jobnet).and_return(@root)
          t1 = Time.now
          event1 = mock(:event1)
          event1.stub(:occurred_at).and_return(t1)
          signal1 = Tengine::Job::Signal.new(event1)
          signal1.stub(:execution).and_return(execution)
          @root.update_with_lock do
            execution.transmit(signal1)
          end
          signal1.reservations.length.should == 1
          signal1.reservations.first.tap do |reservation|
            reservation.event_type_name.should == :"start.job.job.tengine"
          end
          #
          t2 = Time.now
          event2 = mock(:event2)
          event2.stub(:occurred_at).and_return(t2)
          signal2 = Tengine::Job::Signal.new(event2)
          signal2.stub(:execution).and_return(execution)
          @root.reload
          j41 = @root.element("/jn0005/jn4/j41")
          j41.phase_key.should == :ready
          @root.update_with_lock do
            j41.activate(signal2)
          end
          signal2.reservations.map(&:fire_args).should == []
          signal2.reservations.length.should == 0
        end


      end

    end
  end
end
