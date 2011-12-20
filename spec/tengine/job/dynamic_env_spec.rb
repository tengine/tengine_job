# -*- coding: utf-8 -*-
require 'spec_helper'

describe 'hadoop_job_run' do
  before(:all) do
    Tengine.plugins.add(Tengine::Job::DslLoader)
  end

  def load_dsl(filename)
    config = {
      :action => "load",
      :tengined => { :load_path => File.expand_path("../../../../examples/0020_dynamic_env", File.dirname(__FILE__)) },
    }
    @version = File.read(File.expand_path("../../../../examples/VERSION", File.dirname(__FILE__))).strip
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.boot
  end

  describe "基本的なジョブDSL" do
    context "0020_dynamic_env.rb" do
      before do
        Tengine::Job::JobnetTemplate.delete_all
        load_dsl("0020_dynamic_env")
      end

      
    end

  end

end
