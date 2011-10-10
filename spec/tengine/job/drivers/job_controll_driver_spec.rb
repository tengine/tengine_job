# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))
  driver :job_control_driver

  context "rjn0001" do
    before do
      builder = Rjn0001SimpleJobnetBuilder.new
      @jobnet = builder.create_actual
    end

    it "最初のリクエスト" do
      tengine.should_not_fire
      tengine.receive("start.job.tengine", :properties => {
          :root_jobnet_id => @jobnet.id.to_s,
          :target_jobnet_id => @jobnet.id.to_s,
        })
    end
  end

end
