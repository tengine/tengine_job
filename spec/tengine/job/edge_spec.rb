# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::Edge do
  before do
    @event = mock(:event)
    @execution = mock(:execution, :id => "execution_id")
    @signal = Tengine::Job::Signal.new(@event)
    @signal.stub!(:execution).and_return(@execution)
  end

  describe :transmit do
    context "シンプルなケース" do
      # in [j10]
      # [start] --e1-->[s11]--e2-->[end]
      before do
        builder = Rjn0001SimpleJobnetBuilder.new
        builder.create_actual
        @ctx = builder.context
      end

      it "e1をtransmitするとtransmittingになってj11はactivateされてstartingになる" do
        @ctx[:e1].transmit(@signal)
        @ctx[:e1].status_key.should == :transmitting
        @ctx[:j11].phase_key.should == :starting
        @signal.reservations.length.should == 1
        reservation = @signal.reservations.first
        reservation.event_type_name.should == :"start.job.job.tengine"
        reservation.options[:properties][:target_jobnet_id].should == @ctx[:root].id.to_s
        reservation.options[:properties][:target_job_id].should == @ctx[:j11].id.to_s
        reservation.options[:source_name].should =~ %r<^job:.+/\d+/#{@ctx[:root].id.to_s}/#{@ctx[:j11].id.to_s}$>
      end
    end

    context "分岐するケース" do
      # in [j10]
      #              |--e2-->[j11]--e4-->|
      # [S1]--e1-->[F1]                [J1]--e6-->[E1]
      #              |--e3-->[j12]--e5-->|
      before do
        builder = Rjn0002SimpleParallelJobnetBuilder.new
        builder.create_actual
        @ctx = builder.context
      end

      it "e1をtransmitするとe2とe3はtransmittedでj11とj12はstartingになる" do
        @ctx[:e1].transmit(@signal)
        @ctx[:e1].status_key.should == :transmitted
        @ctx[:e2].status_key.should == :transmitting
        @ctx[:e3].status_key.should == :transmitting
        @ctx[:j11].phase_key.should == :starting
        @ctx[:j12].phase_key.should == :starting
        @signal.reservations.length.should == 2
        @signal.reservations.first.tap do |r|
          r.event_type_name.should == :"start.job.job.tengine"
          r.options[:properties][:target_jobnet_id].should == @ctx[:root].id.to_s
          r.options[:properties][:target_job_id].should == @ctx[:j11].id.to_s
          r.options[:source_name].should =~ %r<^job:.+/\d+/#{@ctx[:root].id.to_s}/#{@ctx[:j11].id.to_s}$>
        end
        @signal.reservations.last.tap do |r|
          r.event_type_name.should == :"start.job.job.tengine"
          r.options[:properties][:target_jobnet_id].should == @ctx[:root].id.to_s
          r.options[:properties][:target_job_id].should == @ctx[:j12].id.to_s
          r.options[:source_name].should =~ %r<^job:.+/\d+/#{@ctx[:root].id.to_s}/#{@ctx[:j12].id.to_s}$>
        end
      end

      it "e4をtransmitするとtransmittedになるけどe6は変わらず" do
        @ctx[:e4].transmit(@signal)
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e6].status_key.should == :active
        @signal.reservations.should be_empty
      end

      it "e4をtransmitした後、e5をtransmitするとe6もtransmittedになる" do
        @ctx[:e4].transmit(@signal)
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e5].status_key.should == :active
        @ctx[:e6].status_key.should == :active
        @signal.reservations.should be_empty
        @ctx[:root].save!
        @ctx[:e5].transmit(@signal)
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e5].status_key.should == :transmitted
        @ctx[:J1].activatable?.should == true
        @ctx[:e6].status_key.should == :transmitted
        @signal.reservations.should be_empty
      end
    end

    context "forkとjoinが直接組み合わされるケース" do
      # in [j10]
      #                                                |--e7-->[j14]--e11-->[j16]--e14--->|
      #              |--e2-->[j11]--e4-->[j13]--e6-->[F2]                                 |
      # [S1]--e1-->[F1]                                |--e8-->[J1]--e12-->[j17]--e15-->[J2]--e16-->[E2]
      #              |                                 |--e9-->[J1]                       |
      #              |--e3-->[j12]------e5---------->[F3]                                 |
      #                                                |--e10---->[j15]---e13------------>|
      before do
        builder = Rjn0003ForkJoinJobnetBuilder.new
        builder.create_actual
        @ctx = builder.context
      end

      it "e6.transmitしてもe12には伝搬しない" do
        @ctx[:e6].transmit(@signal)
        @ctx[:e6].status_key.should == :transmitted
        @ctx[:e7].status_key.should == :transmitting
        @ctx[:e8].status_key.should == :transmitted
        @ctx[:e12].status_key.should == :active
        @signal.reservations.length.should == 1
        @signal.reservations.first.tap do |r|
          r.event_type_name.should == :"start.job.job.tengine"
          r.options[:properties][:target_jobnet_id].should == @ctx[:root].id.to_s
          r.options[:properties][:target_job_id].should == @ctx[:j14].id.to_s
          r.options[:source_name].should =~ %r<^job:.+/\d+/#{@ctx[:root].id.to_s}/#{@ctx[:j14].id.to_s}$>
        end
      end

      it "e5とe6の両方をtransmitするとe12に伝搬する" do
        @ctx[:e6].transmit(@signal)
        @ctx[:e6].status_key.should == :transmitted
        @ctx[:e7].status_key.should == :transmitting
        @ctx[:e8].status_key.should == :transmitted
        @ctx[:e9].status_key.should == :active
        @ctx[:e10].status_key.should == :active
        @ctx[:e12].status_key.should == :active
        @signal.reservations.clear
        @ctx[:e5].transmit(@signal)
        @ctx[:e6].status_key.should == :transmitted
        @ctx[:e7].status_key.should == :transmitting
        @ctx[:e8].status_key.should == :transmitted
        @ctx[:e9].status_key.should == :transmitted
        @ctx[:e10].status_key.should == :transmitting
        @ctx[:e12].status_key.should == :transmitting
        @signal.reservations.length.should == 2
        @signal.reservations.first.tap do |r|
          r.event_type_name.should == :"start.job.job.tengine"
          r.options[:properties][:target_jobnet_id].should == @ctx[:root].id.to_s
          r.options[:properties][:target_job_id].should == @ctx[:j17].id.to_s
        end
        @signal.reservations.last.tap do |r|
          r.event_type_name.should == :"start.job.job.tengine"
          r.options[:properties][:target_jobnet_id].should == @ctx[:root].id.to_s
          r.options[:properties][:target_job_id].should == @ctx[:j15].id.to_s
        end
      end

    end
  end

end
