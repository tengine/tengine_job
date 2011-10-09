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
        @ctx[:e1].transmit
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
        @ctx[:e1].transmit
        @ctx[:e1].status_key.should == :transmitted
        @ctx[:e2].status_key.should == :transmitting
        @ctx[:e3].status_key.should == :transmitting
        @ctx[:j11].phase_key.should == :starting
        @ctx[:j12].phase_key.should == :starting
      end

      it "e4をtransmitするとtransmittedになるけどe6は変わらず" do
        @ctx[:e4].transmit
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e6].status_key.should == :active
      end

      it "e4をtransmitした後、e5をtransmitするとe6もtransmittedになる" do
        @ctx[:e4].transmit
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e5].status_key.should == :active
        @ctx[:e6].status_key.should == :active
        @ctx[:root].save!
        @ctx[:e5].transmit
        @ctx[:e4].status_key.should == :transmitted
        @ctx[:e5].status_key.should == :transmitted
        @ctx[:J1].possible?.should == true
        @ctx[:e6].status_key.should == :transmitted
      end
    end

    context "forkとjoinが直接組み合わされるケース" do
      # in [j10]
      #                                                |--e7-->[j14]--e11-->[j16]--e14--->|
      #              |--e1-->[j11]--e4-->[j13]--e6-->[F2]                                 |
      # [S1]--e1-->[F1]                                |--e8-->[J1]--e12-->[j17]--e15-->[J2]--e16-->[E2]
      #              |                                 |--e9-->[J1]                       |
      #              |--e3-->[j12]------e5---------->[F3]                                 |
      #                                                |--e10---->[j15]---e13------------>|
      before do
        @j10 = Tengine::Job::RootJobnetActual.new(:name => "j10")
        @j10.children << @start = Tengine::Job::Start.new
        @j10.children << @fork1 = Tengine::Job::Fork.new
        @j10.children << @j11   = Tengine::Job::ScriptActual.new(:name => "j11")
        @j10.children << @j12   = Tengine::Job::ScriptActual.new(:name => "j12")
        @j10.children << @j13   = Tengine::Job::ScriptActual.new(:name => "j13")
        @j10.children << @fork2 = Tengine::Job::Fork.new
        @j10.children << @fork3 = Tengine::Job::Fork.new
        @j10.children << @join1 = Tengine::Job::Join.new
        @j10.children << @j14   = Tengine::Job::ScriptActual.new(:name => "j14")
        @j10.children << @j15   = Tengine::Job::ScriptActual.new(:name => "j15")
        @j10.children << @j16   = Tengine::Job::ScriptActual.new(:name => "j16")
        @j10.children << @j17   = Tengine::Job::ScriptActual.new(:name => "j17")
        @j10.children << @join2 = Tengine::Job::Join.new
        @j10.children << @end   = Tengine::Job::End.new
        @j10.edges << @e1 = Tengine::Job::Edge.new(:origin_id => @start.id, :destination_id => @fork1.id)
        @j10.edges << @e2 = Tengine::Job::Edge.new(:origin_id => @fork1.id, :destination_id => @j11.id  )
        @j10.edges << @e3 = Tengine::Job::Edge.new(:origin_id => @fork1.id, :destination_id => @j12.id  )
        @j10.edges << @e4 = Tengine::Job::Edge.new(:origin_id => @j11.id  , :destination_id => @j13.id  )
        @j10.edges << @e5 = Tengine::Job::Edge.new(:origin_id => @j12.id  , :destination_id => @fork3.id)
        @j10.edges << @e6 = Tengine::Job::Edge.new(:origin_id => @j13.id  , :destination_id => @fork2.id)
        @j10.edges << @e7 = Tengine::Job::Edge.new(:origin_id => @fork2.id, :destination_id => @j14.id  )
        @j10.edges << @e8 = Tengine::Job::Edge.new(:origin_id => @fork2.id, :destination_id => @join1.id)
        @j10.edges << @e9 = Tengine::Job::Edge.new(:origin_id => @fork3.id, :destination_id => @join1.id)
        @j10.edges << @e10 = Tengine::Job::Edge.new(:origin_id => @fork3.id, :destination_id => @j15.id  )
        @j10.edges << @e11 = Tengine::Job::Edge.new(:origin_id => @j14.id  , :destination_id => @j16.id  )
        @j10.edges << @e12 = Tengine::Job::Edge.new(:origin_id => @join1.id, :destination_id => @j17.id  )
        @j10.edges << @e13 = Tengine::Job::Edge.new(:origin_id => @j15.id  , :destination_id => @join2.id)
        @j10.edges << @e14 = Tengine::Job::Edge.new(:origin_id => @j16.id  , :destination_id => @join2.id)
        @j10.edges << @e15 = Tengine::Job::Edge.new(:origin_id => @j17.id  , :destination_id => @join2.id)
        @j10.edges << @e16 = Tengine::Job::Edge.new(:origin_id => @join2.id, :destination_id => @end.id  )
        @j10.save!
      end

      it "e6.transmitしてもe12には伝搬しない" do
        @e6.transmit
        @e6.status_key.should == :transmitted
        @e7.status_key.should == :transmitting
        @e8.status_key.should == :transmitted
        @e12.status_key.should == :active
      end

      it "e5とe6の両方をtransmitするとe12に伝搬する" do
        @e6.transmit
        @e6.status_key.should == :transmitted
        @e7.status_key.should == :transmitting
        @e8.status_key.should == :transmitted
        @e9.status_key.should == :active
        @e10.status_key.should == :active
        @e12.status_key.should == :active

        @e5.transmit
        @e6.status_key.should == :transmitted
        @e7.status_key.should == :transmitting
        @e8.status_key.should == :transmitted
        @e9.status_key.should == :transmitted
        @e10.status_key.should == :transmitting
        @e12.status_key.should == :transmitting
      end

    end
  end

end
