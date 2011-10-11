# -*- coding: utf-8 -*-
require 'spec_helper'
require 'time'

describe Tengine::Job::Execution do
  describe :actual_estimated_end do
    context "strted_atがnilならnil" do
      subject{ Tengine::Job::Execution.new(:started_at => nil, :estimated_time => 10.minutes) }
      its(:actual_estimated_end) { should == nil }
    end

    context "strted_atが設定されていたらstarted_atに見積もり時間を足した時間" do
      subject do
        Tengine::Job::Execution.new(
          :started_at => Time.parse("2011/10/11 01:00Z"),
          :estimated_time => 10 * 60)
      end
      it { subject.actual_estimated_end.iso8601.should == Time.parse("2011/10/11 01:10Z").iso8601 }
    end
  end
end
