# -*- coding: utf-8 -*-
require 'spec_helper'

describe "job DSL examples" do
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

  example_dir = File.expand_path("../../../../examples", File.dirname(__FILE__))

  context "load_dsl" do
    Dir.glob("#{example_dir}/*.rb") do |job_dsl_path|
      it do
        Tengine::Job::Vertex.delete_all
        Tengine::Job::Vertex.count.should == 0
        expect {
          load_dsl(File.basename(job_dsl_path))
        }.to_not raise_error
        Tengine::Job::Vertex.count.should_not == 0
      end
    end
  end

end
