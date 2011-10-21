# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::Jobnet do

  context "基本機能" do
    before do
      @j1000 = Tengine::Job::JobnetTemplate.new(:name => "j1000").with_start
      @j1000.children << @j1100 = Tengine::Job::JobnetTemplate.new(:name => "j1100").with_start
      @j1100.children << @j1110 = Tengine::Job::JobnetTemplate.new(:name => "j1110", :script => "j1110.sh")
      @j1100.children << @j1120 = Tengine::Job::JobnetTemplate.new(:name => "j1120", :script => "j1120.sh")
      @j1000.children << @j1200 = Tengine::Job::JobnetTemplate.new(:name => "j1200").with_start
      @j1200.children << @j1210 = Tengine::Job::JobnetTemplate.new(:name => "j1210").with_start
      @j1210.children << @j1211 = Tengine::Job::JobnetTemplate.new(:name => "j1211", :script => "j1211.sh")
      @j1210.children << @j1212 = Tengine::Job::JobnetTemplate.new(:name => "j1212", :script => "j1212.sh")
      @j1200.children << @j1220 = Tengine::Job::JobnetTemplate.new(:name => "j1220").with_start
      @j1220.children << @j1221 = Tengine::Job::JobnetTemplate.new(:name => "j1221", :script => "j1221.sh")
      @j1220.children << @j1222 = Tengine::Job::JobnetTemplate.new(:name => "j1222", :script => "j1222.sh")
      @j1000.prepare_end
      @j1100.prepare_end
      @j1200.prepare_end
      @j1210.prepare_end
      @j1220.prepare_end
      @j1000.build_sequencial_edges
      @j1100.build_sequencial_edges
      @j1200.build_sequencial_edges
      @j1210.build_sequencial_edges
      @j1220.build_sequencial_edges
      @j1000.save!
    end

    name_to_name_path = {
      'j1000' => '/j1000',
      'j1100' => '/j1000/j1100',
      'j1110' => '/j1000/j1100/j1110',
      'j1120' => '/j1000/j1100/j1120',
      'j1200' => '/j1000/j1200',
      'j1210' => '/j1000/j1200/j1210',
      'j1211' => '/j1000/j1200/j1210/j1211',
      'j1212' => '/j1000/j1200/j1210/j1212',
      'j1220' => '/j1000/j1200/j1220',
      'j1221' => '/j1000/j1200/j1220/j1221',
      'j1222' => '/j1000/j1200/j1220/j1222',
    }

    describe :name_path do
      name_to_name_path.each do |node_name, name_path|
        context "#{node_name}'s name_path" do
          subject{ instance_variable_get(:"@#{node_name}") }
          its(:name_path){ should == name_path}
        end
      end
    end

    describe 'find_descendant系' do
      all_node_names = %w[j1000 j1100 j1110 j1120 j1200 j1210 j1211 j1212 j1220 j1221 j1222]

      context "ルートはルート自身を見つけることができない" do
        it :find_desendant do
          root = @j1000
          root.find_descendant(root.id).should be_nil
        end

        it :find_desendant_by_name_path do
          root = @j1000
          root.find_descendant_by_name_path('/j1000').should be_nil
        end
      end

      (all_node_names -%w[j1000]).each do |node_name|
        context "ルートから#{node_name}を見つけることができる" do
          context :find_descendant do
            it "BSON::ObjectId" do
              root = @j1000
              node = instance_variable_get(:"@#{node_name}")
              actual = root.find_descendant(node.id)
              actual.id.should == node.id
              actual.name.should == node.name
            end

            it "String" do
              root = @j1000
              node = instance_variable_get(:"@#{node_name}")
              actual = root.find_descendant(node.id.to_s)
              actual.id.should == node.id
              actual.name.should == node.name
            end
          end

          it :find_descendant_by_name_path do
            root = @j1000
            node = instance_variable_get(:"@#{node_name}")
            actual = root.find_descendant_by_name_path(name_to_name_path[node_name])
            actual.id.should == node.id
            actual.name.should == node.name
          end
        end
      end

      (all_node_names -%w[j1000 j1100 j1110 j1120 j1200]).each do |node_name|
        context "j1200から#{node_name}を見つけることができる" do
          it :find_descendant do
            base = @j1200
            node = instance_variable_get(:"@#{node_name}")
            actual = base.find_descendant(node.id)
            actual.id.should == node.id
            actual.name.should == node.name
          end

          it :find_descendant_by_name_path do
            base = @j1200
            node = instance_variable_get(:"@#{node_name}")
            actual = base.find_descendant_by_name_path(name_to_name_path[node_name])
            actual.id.should == node.id
            actual.name.should == node.name
          end

        end
      end

      %w[j1000 j1100 j1110 j1120 j1200].each do |node_name|
        context "j1200から#{node_name}を見つけることはできない" do
          it :find_descendant do
            base = @j1200
            node = instance_variable_get(:"@#{node_name}")
            base.find_descendant(node.id).should == nil
          end

          it :find_descendant_by_name_path do
            base = @j1200
            node = instance_variable_get(:"@#{node_name}")
            base.find_descendant_by_name_path(name_to_name_path[node_name]).should == nil
          end
        end
      end
    end

    describe :find_descendant_edge do
      before do
        @j1000_start = @j1000.edges[0] # to j1100
        @j1100_next  = @j1000.edges[1] # to j1200
        @j1200_next  = @j1000.edges[2] # to j1000's end

        @j1100_start = @j1100.edges[0] # to j1110
        @j1110_next  = @j1100.edges[1] # to j1120
        @j1120_next  = @j1100.edges[2] # to j1100's end

        @j1200_start = @j1200.edges[0] # to j1210
        @j1210_next  = @j1200.edges[1] # to j1220
        @j1220_next  = @j1200.edges[2] # to j1200's end

        @j1210_start = @j1210.edges[0] # to j1211
        @j1211_next  = @j1210.edges[1] # to j1212
        @j1212_next  = @j1210.edges[2] # to j1210's end

        @j1220_start = @j1220.edges[0] # to j1221
        @j1221_next  = @j1220.edges[1] # to j1222
        @j1222_next  = @j1220.edges[2] # to j1220's end
      end

      edge_names = %w[
        j1000_start j1100_next j1200_next
        j1100_start j1110_next j1120_next
        j1200_start j1210_next j1220_next
        j1210_start j1211_next j1212_next
        j1220_start j1221_next j1222_next
      ]

      edge_names.each do |edge_name|
        context "edge_name check" do
          case edge_name
          when /_start$/ then

            it "should be the edge from start to other" do
              owner_name = edge_name.sub(/_start$/, '')
              owner = instance_variable_get(:"@#{owner_name}")
              start = owner.children.first
              edge = instance_variable_get(:"@#{edge_name}")
              edge.origin_id.should == start.id
            end

          when /_next$/ then

            it "should be the edge from vertex to other" do
              origin_name = edge_name.sub(/_next$/, '')
              origin = instance_variable_get(:"@#{origin_name}")
              edge = instance_variable_get(:"@#{edge_name}")
              edge.origin_id.should == origin.id
              owner = origin.parent
              edge.owner.id.should == owner.id
            end

          end
        end
      end

      edge_names.each do |edge_name|
        it "ルートからエッジ#{edge_name}を参照できます" do
          edge = instance_variable_get(:"@#{edge_name}")
          found = @j1000.find_descendant_edge(edge.id)
          found.id.should == edge.id
        end
      end

    end

  end

end
