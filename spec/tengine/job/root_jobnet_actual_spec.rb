# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::RootJobnetActual do

  context :update_with_lock do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      builder.create_actual
      @ctx = builder.context
    end

    it "updateで更新できる" do
      root = @ctx[:root]
      j11 = root.find_descendant(@ctx[:j11].id)
      j11.executing_pid = "1111"
      root.save!
      #
      loaded = Tengine::Job::RootJobnetActual.find(root.id)
      loaded.find_descendant(@ctx[:j11].id).executing_pid.should == "1111"
    end

    it "update_with_lockで更新できる" do
      count = 0
      root = @ctx[:root]
      root.update_with_lock do
        count += 1
        j11 = root.find_descendant(@ctx[:j11].id)
        j11.executing_pid = "1111"
      end
      count.should == 1
      #
      loaded = Tengine::Job::RootJobnetActual.find(root.id)
      loaded.find_descendant(@ctx[:j11].id).executing_pid.should == "1111"
    end

  end

end
