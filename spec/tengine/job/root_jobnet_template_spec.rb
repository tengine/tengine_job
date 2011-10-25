# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::RootJobnetTemplate do

  describe :generate do
    context "rjn0001" do
      before do
        Tengine::Job::Vertex.delete_all
        builder = Rjn0001SimpleJobnetBuilder.new
        @jobnet = builder.create_template
        @ctx = builder.context
      end

      it "実行用ジョブネットを生成する" do
        root = @jobnet.generate
        root.should be_a(Tengine::Job::RootJobnetActual)
        root.children.length.should == 4
        root.children[0].should be_a(Tengine::Job::Start)
        root.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j11"}
        root.children[2].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j12"}
        root.children[3].should be_a(Tengine::Job::End)
        root.edges.length.should == 3
        root.edges[0].tap{|edge| edge.origin.should == root.children[0]; edge.destination.should == root.children[1]}
        root.edges[1].tap{|edge| edge.origin.should == root.children[1]; edge.destination.should == root.children[2]}
        root.edges[2].tap{|edge| edge.origin.should == root.children[2]; edge.destination.should == root.children[3]}
        root.template.id.should == @jobnet.id
      end
    end

    context "rjn0002" do
      before do
        Tengine::Job::Vertex.delete_all
        builder = Rjn0002SimpleParallelJobnetBuilder.new
        @jobnet = builder.create_template
        @ctx = builder.context
      end

      it "実行用ジョブネットを生成する" do
        root = @jobnet.generate
        root.should be_a(Tengine::Job::RootJobnetActual)
        root.children.length.should == 6
        root.children[0].should be_a(Tengine::Job::Start)
        root.children[1].should be_a(Tengine::Job::Fork)
        root.children[2].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j11"}
        root.children[3].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j12"}
        root.children[4].should be_a(Tengine::Job::Join)
        root.children[5].should be_a(Tengine::Job::End)
        root.edges.length.should == 6
        root.edges[0].tap{|edge| edge.origin.should == root.children[0]; edge.destination.should == root.children[1]}
        root.edges[1].tap{|edge| edge.origin.should == root.children[1]; edge.destination.should == root.children[2]}
        root.edges[2].tap{|edge| edge.origin.should == root.children[1]; edge.destination.should == root.children[3]}
        root.edges[3].tap{|edge| edge.origin.should == root.children[2]; edge.destination.should == root.children[4]}
        root.edges[4].tap{|edge| edge.origin.should == root.children[3]; edge.destination.should == root.children[4]}
        root.edges[5].tap{|edge| edge.origin.should == root.children[4]; edge.destination.should == root.children[5]}
        root.template.id.should == @jobnet.id
      end
    end

    context "rjn0007" do
      before do
        Tengine::Job::Vertex.delete_all
        builder = Rjn0007NestedAndFinallyBuilder.new
        @jobnet = builder.create_template
        @ctx = builder.context
      end

      it "実行用ジョブネットを生成する" do
        root = @jobnet.generate
        root.should be_a(Tengine::Job::RootJobnetActual)
        root.children.length.should == 5
        root.children[0].should be_a(Tengine::Job::Start)
        root.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1000"}
        root.children[2].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j2000"}
        root.children[3].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.jobnet_type_key.should == :finally}
        root.children[4].should be_a(Tengine::Job::End)
        root.edges.length.should == 3
        root.edges[0].tap{|edge| edge.origin.should == root.children[0]; edge.destination.should == root.children[1]}
        root.edges[1].tap{|edge| edge.origin.should == root.children[1]; edge.destination.should == root.children[2]}
        root.edges[2].tap{|edge| edge.origin.should == root.children[2]; edge.destination.should == root.children[4]}
        root.children[1].tap do |j1000|
          j1000.children.length.should == 5
          j1000.children[0].should be_a(Tengine::Job::Start)
          j1000.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1100"}
          j1000.children[2].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1200"}
          j1000.children[3].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.jobnet_type_key.should == :finally}
          j1000.children[4].should be_a(Tengine::Job::End)
          j1000.edges.length.should == 3
          j1000.edges[0].tap{|edge| edge.origin.should == j1000.children[0]; edge.destination.should == j1000.children[1]}
          j1000.edges[1].tap{|edge| edge.origin.should == j1000.children[1]; edge.destination.should == j1000.children[2]}
          j1000.edges[2].tap{|edge| edge.origin.should == j1000.children[2]; edge.destination.should == j1000.children[4]}
          j1000.children[1].tap do |j1100|
            j1100.children.length.should == 3
            j1100.children[0].should be_a(Tengine::Job::Start)
            j1100.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1110"}
            j1100.children[2].should be_a(Tengine::Job::End)
            j1100.edges.length.should == 2
            j1100.edges[0].tap{|edge| edge.origin.should == j1100.children[0]; edge.destination.should == j1100.children[1]}
            j1100.edges[1].tap{|edge| edge.origin.should == j1100.children[1]; edge.destination.should == j1100.children[2]}
          end
          j1000.children[2].tap do |j1200|
            j1200.children.length.should == 3
            j1200.children[0].should be_a(Tengine::Job::Start)
            j1200.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1210"}
            j1200.children[2].should be_a(Tengine::Job::End)
            j1200.edges.length.should == 2
            j1200.edges[0].tap{|edge| edge.origin.should == j1200.children[0]; edge.destination.should == j1200.children[1]}
            j1200.edges[1].tap{|edge| edge.origin.should == j1200.children[1]; edge.destination.should == j1200.children[2]}
          end
          j1000.children[3].tap do |j1f00|
            j1f00.children.length.should == 4
            j1f00.children[0].should be_a(Tengine::Job::Start)
            j1f00.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1f10"}
            j1f00.children[2].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.jobnet_type_key.should == :finally}
            j1f00.children[3].should be_a(Tengine::Job::End)
            j1f00.edges.length.should == 2
            j1f00.edges[0].tap{|edge| edge.origin.should == j1f00.children[0]; edge.destination.should == j1f00.children[1]}
            j1f00.edges[1].tap{|edge| edge.origin.should == j1f00.children[1]; edge.destination.should == j1f00.children[3]}
            j1f00.children[1].tap do |j1f10|
              j1f10.children.length.should == 3
              j1f10.children[0].should be_a(Tengine::Job::Start)
              j1f10.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1f11"}
              j1f10.children[2].should be_a(Tengine::Job::End)
              j1f10.edges.length.should == 2
              j1f10.edges[0].tap{|edge| edge.origin.should == j1f10.children[0]; edge.destination.should == j1f10.children[1]}
              j1f10.edges[1].tap{|edge| edge.origin.should == j1f10.children[1]; edge.destination.should == j1f10.children[2]}
            end
            j1f00.children[2].tap do |j1ff0|
              j1ff0.children.length.should == 3
              j1ff0.children[0].should be_a(Tengine::Job::Start)
              j1ff0.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j1ff1"}
              j1ff0.children[2].should be_a(Tengine::Job::End)
              j1ff0.edges.length.should == 2
              j1ff0.edges[0].tap{|edge| edge.origin.should == j1ff0.children[0]; edge.destination.should == j1ff0.children[1]}
              j1ff0.edges[1].tap{|edge| edge.origin.should == j1ff0.children[1]; edge.destination.should == j1ff0.children[2]}
            end
          end
        end
        root.children[2].tap do |j2000|
          j2000.children.length.should == 3
          j2000.children[0].should be_a(Tengine::Job::Start)
          j2000.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "j2100"}
          j2000.children[2].should be_a(Tengine::Job::End)
          j2000.edges.length.should == 2
          j2000.edges[0].tap{|edge| edge.origin.should == j2000.children[0]; edge.destination.should == j2000.children[1]}
          j2000.edges[1].tap{|edge| edge.origin.should == j2000.children[1]; edge.destination.should == j2000.children[2]}
        end
        root.children[3].tap do |jf000|
          jf000.children.length.should == 3
          jf000.children[0].should be_a(Tengine::Job::Start)
          jf000.children[1].tap{|j| j.should be_a(Tengine::Job::JobnetActual); j.name.should == "jf100"}
          jf000.children[2].should be_a(Tengine::Job::End)
          jf000.edges.length.should == 2
          jf000.edges[0].tap{|edge| edge.origin.should == jf000.children[0]; edge.destination.should == jf000.children[1]}
          jf000.edges[1].tap{|edge| edge.origin.should == jf000.children[1]; edge.destination.should == jf000.children[2]}
        end
        root.template.id.should == @jobnet.id
      end

    end

  end

  describe :execute do

    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      @jobnet = builder.create_template
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @jobnet.id,
        })
    end

    it "create Execution" do
      execution = @jobnet.execute
      execution.should be_a(Tengine::Job::Execution)
      root_jobnet_actual = execution.root_jobnet
      root_jobnet_actual.should be_a(Tengine::Job::RootJobnetActual)
      root_jobnet_actual.template.id.should == @jobnet.id
    end

  end

end
