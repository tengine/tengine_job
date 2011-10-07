# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::Edge do
  describe :transmit do
    context "シンプルなケース" do
      # in [j10]
      # [start] --e11--> [j11] --e12--> [end]
      before do
        @j10 = Tengine::Job::JobnetActual.new(:name => "j10")
        @j10.children << @j11 = Tengine::Job::JobnetActual.new(:name => "j11")
        @j10.prepare_end
        @j10.build_sequencial_edges
        @j10.save!
        #
        @j10_start = @j10.children[0]
        @j10_end   = @j10.children[2]
        @e11 = @j10.edges[0]
        @e12 = @j10.edges[1]
      end

      it "e11をtransmitするとtransmittingになってj11はactivateされてstartingになる" do
        @e11.transmit
        @e11.status_key.should == :transmitting
        @j11.phase_key.should == :starting
      end
    end

    context "分岐するケース" do
      # in [j10]
      #                   |---e12--->[j11]---e14--->|
      # [start]---e11--->[F]                       [J]---e16--->[end]
      #                   |---e13--->[j12]---e15--->|
      before do
        @j10 = Tengine::Job::JobnetActual.new(:name => "j10")
        @j10.children << @start = Tengine::Job::Start.new
        @j10.children << @fork1 = Tengine::Job::Fork.new
        @j10.children << @j11   = Tengine::Job::JobnetActual.new(:name => "j11")
        @j10.children << @j12   = Tengine::Job::JobnetActual.new(:name => "j12")
        @j10.children << @join1 = Tengine::Job::Join.new
        @j10.children << @end   = Tengine::Job::End.new
        @j10.edges << @e11 = Tengine::Job::Edge.new(:origin_id => @start.id, :destination_id => @fork1.id)
        @j10.edges << @e12 = Tengine::Job::Edge.new(:origin_id => @fork1.id, :destination_id => @j11.id)
        @j10.edges << @e13 = Tengine::Job::Edge.new(:origin_id => @fork1.id, :destination_id => @j12.id)
        @j10.edges << @e14 = Tengine::Job::Edge.new(:origin_id => @j11.id  , :destination_id => @join1.id)
        @j10.edges << @e15 = Tengine::Job::Edge.new(:origin_id => @j12.id  , :destination_id => @join1.id)
        @j10.edges << @e16 = Tengine::Job::Edge.new(:origin_id => @join1.id, :destination_id => @end.id)
        @j10.save!
      end

      it "e11をtransmitするとe12とe13はtransmittedでj11とj12はstartingになる" do
        @e11.transmit
        @e11.status_key.should == :transmitted
        @e12.status_key.should == :transmitting
        @e13.status_key.should == :transmitting
        @j11.phase_key.should == :starting
        @j12.phase_key.should == :starting
      end

      it "e14をtransmitするとtransmittedになるけどe16は変わらず" do
        @e14.transmit
        @e14.status_key.should == :transmitted
        @e16.status_key.should == :active
      end

      it "e14をtransmitした後、e15をtransmitするとe16もtransmittedになる" do
        @e14.transmit
        @e14.status_key.should == :transmitted
        @e15.status_key.should == :active
        @e16.status_key.should == :active
        @j10.save!
        @e15.transmit
        @e14.status_key.should == :transmitted
        @e15.status_key.should == :transmitted
        @join1.possible?.should == true
        @e16.status_key.should == :transmitted
      end
    end

    context "forkとjoinが直接組み合わされるケース" do
      # in [j10]
      #                                                       |--e17-->[j14]--e21-->[j16]--e24--->|
      #                  |--e12-->[j11]--e14-->[j13]--e16-->[F2]                                  |
      # [start]--e11-->[F1]                                   |--e18-->[J1]--e22-->[j17]--e25-->[J2]--e26-->[end]
      #                  |                                    |--e19-->                           |
      #                  |--e13-->[j12] ------e15---------->[F3]                                  |
      #                                                       |--e20---->[j15]---e23------------->|
      before do
        @j10 = Tengine::Job::JobnetActual.new(:name => "j10")
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
        @j10.edges << @e11 = Tengine::Job::Edge.new(:origin_id => @start.id, :destination_id => @fork1.id)
        @j10.edges << @e12 = Tengine::Job::Edge.new(:origin_id => @fork1.id, :destination_id => @j11.id  )
        @j10.edges << @e13 = Tengine::Job::Edge.new(:origin_id => @fork1.id, :destination_id => @j12.id  )
        @j10.edges << @e14 = Tengine::Job::Edge.new(:origin_id => @j11.id  , :destination_id => @j13.id  )
        @j10.edges << @e15 = Tengine::Job::Edge.new(:origin_id => @j12.id  , :destination_id => @fork3.id)
        @j10.edges << @e16 = Tengine::Job::Edge.new(:origin_id => @j13.id  , :destination_id => @fork2.id)
        @j10.edges << @e17 = Tengine::Job::Edge.new(:origin_id => @fork2.id, :destination_id => @j14.id  )
        @j10.edges << @e18 = Tengine::Job::Edge.new(:origin_id => @fork2.id, :destination_id => @join1.id)
        @j10.edges << @e19 = Tengine::Job::Edge.new(:origin_id => @fork3.id, :destination_id => @join1.id)
        @j10.edges << @e20 = Tengine::Job::Edge.new(:origin_id => @fork3.id, :destination_id => @j15.id  )
        @j10.edges << @e21 = Tengine::Job::Edge.new(:origin_id => @j14.id  , :destination_id => @j16.id  )
        @j10.edges << @e22 = Tengine::Job::Edge.new(:origin_id => @join1.id, :destination_id => @j17.id  )
        @j10.edges << @e23 = Tengine::Job::Edge.new(:origin_id => @j15.id  , :destination_id => @join2.id)
        @j10.edges << @e24 = Tengine::Job::Edge.new(:origin_id => @j16.id  , :destination_id => @join2.id)
        @j10.edges << @e25 = Tengine::Job::Edge.new(:origin_id => @j17.id  , :destination_id => @join2.id)
        @j10.edges << @e26 = Tengine::Job::Edge.new(:origin_id => @join2.id, :destination_id => @end.id  )
        @j10.save!
      end

      it "e16.transmitしてもe22には伝搬しない" do
        @e16.transmit
        @e16.status_key.should == :transmitted
        @e17.status_key.should == :transmitting
        @e18.status_key.should == :transmitted
        @e22.status_key.should == :active
      end

      it "e15とe16の両方をtransmitするとe22に伝搬する" do
        @e16.transmit
        @e16.status_key.should == :transmitted
        @e17.status_key.should == :transmitting
        @e18.status_key.should == :transmitted
        @e19.status_key.should == :active
        @e20.status_key.should == :active
        @e22.status_key.should == :active

        @e15.transmit
        @e16.status_key.should == :transmitted
        @e17.status_key.should == :transmitting
        @e18.status_key.should == :transmitted
        @e19.status_key.should == :transmitted
        @e20.status_key.should == :transmitting
        @e22.status_key.should == :transmitting
      end

    end
  end

end
