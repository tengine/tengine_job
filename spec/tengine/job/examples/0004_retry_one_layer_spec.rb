# -*- coding: utf-8 -*-
require 'spec_helper'

describe "0004_retry_on_layer" do
  before(:all) do
    Tengine.plugins.add(Tengine::Job::DslLoader)
  end

  def load_dsl(filename)
    config = {
      :action => "load",
      :tengined => { :load_path => File.expand_path("../../../../examples/#{filename}", File.dirname(__FILE__)) },
    }
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.boot
  end

  describe "基本的なジョブDSL" do
    it do
      Tengine::Job::JobnetTemplate.delete_all
      begin
        load_dsl("0004_retry_one_layer.rb")
      rescue Exception => e
        v = Tengine::Job::Vertex::AllVisitorWithEdge.new do |obj|
          if obj.respond_to?(:errors) && !obj.errors.empty?
            puts obj.errors.inspect
            true
          end
        end
        e.document.accept_visitor(v)
        raise
      end
    end
  end

end
