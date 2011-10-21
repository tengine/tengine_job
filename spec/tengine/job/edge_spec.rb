# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::Edge do
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
        jobs = @ctx[:e1].transmit(Tengine::Job::Signal.new)
        jobs.should == [@ctx[:j11]]
        @ctx[:e1].status_key.should == :transmitting
        @ctx[:j11].phase_key.should == :starting
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
        jobs = @ctx[:e1].transmit(Tengine::Job::Signal.new)
        jobs.should == [@ctx[:j11], @ctx[:j12]]
        @ctx[:e1].status_key.should == :transmitted
        @ctx[:e2].status_key.should == :transmitting
        @ctx[:e3].status_key.should == :transmitting
        @ctx[:j11].phase_key.should == :starting
        @ctx[:j12].phase_key.should == :starting
      end

      it "e4をtransmitするとtransmittedになるけどe6は変わらず" do
        jobs = @ctx[:e4].transmit(Tengine::Job::Signal.new)
        jobs.should == []
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e6].status_key.should == :active
      end

      it "e4をtransmitした後、e5をtransmitするとe6もtransmittedになる" do
        jobs = @ctx[:e4].transmit(Tengine::Job::Signal.new)
        jobs.should == []
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e5].status_key.should == :active
        @ctx[:e6].status_key.should == :active
        @ctx[:root].save!
        jobs = @ctx[:e5].transmit(Tengine::Job::Signal.new)
        jobs.should == []
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e5].status_key.should == :transmitted
        @ctx[:J1].possible?.should == true
        @ctx[:e6].status_key.should == :transmitted
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
        jobs = @ctx[:e6].transmit(Tengine::Job::Signal.new)
        jobs.should == [@ctx[:j14]]
        @ctx[:e6].status_key.should == :transmitted
        @ctx[:e7].status_key.should == :transmitting
        @ctx[:e8].status_key.should == :transmitted
        @ctx[:e12].status_key.should == :active
      end

      it "e5とe6の両方をtransmitするとe12に伝搬する" do
        jobs = @ctx[:e6].transmit(Tengine::Job::Signal.new)
        jobs.should == [@ctx[:j14]]
        @ctx[:e6].status_key.should == :transmitted
        @ctx[:e7].status_key.should == :transmitting
        @ctx[:e8].status_key.should == :transmitted
        @ctx[:e9].status_key.should == :active
        @ctx[:e10].status_key.should == :active
        @ctx[:e12].status_key.should == :active

        jobs = @ctx[:e5].transmit(Tengine::Job::Signal.new)
        jobs.should == [ @ctx[:j17], @ctx[:j15] ]
        @ctx[:e6].status_key.should == :transmitted
        @ctx[:e7].status_key.should == :transmitting
        @ctx[:e8].status_key.should == :transmitted
        @ctx[:e9].status_key.should == :transmitted
        @ctx[:e10].status_key.should == :transmitting
        @ctx[:e12].status_key.should == :transmitting
      end

    end
  end

end
