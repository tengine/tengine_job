# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../lib/tengine/job/drivers/jobnet_control_driver.rb", File.dirname(__FILE__))
  driver :jobnet_control_driver

  before do
    @now = Time.now
    Time.stub!(:now).and_return(@now)
  end

  # in [rjn0001]
  # (S1) --e1-->(j11)--e2-->(j12)--e3-->(E1)
  context "rjn0001" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @base_props = {
        :execution_id => @execution.id.to_s,
        :root_jobnet_id => @root.id.to_s,
        :target_jobnet_id => @root.id.to_s,
      }
    end

    it "ジョブネット起動イベントを受信したら" do
      @root.phase_key = :ready
      @root.save!
      tengine.should_fire(:"start.job.job.tengine",
        :source_name => @ctx[:j11].name_as_resource,
        :properties => {
          :target_job_id => @ctx[:j11].id.to_s,
        }.update(@base_props))
      tengine.receive("start.jobnet.job.tengine", :properties => @base_props)
      @root.reload
      @root.phase_key.should == :running
      @root.started_at.utc.iso8601.should == @now.utc.iso8601
      @ctx.edge(:e1).status_key.should == :transmitting
      @ctx.vertex(:j11).phase_key.should == :ready
    end


    context 'j11を実行' do
      it "成功した場合" do
        @root.phase_key = :running
        @ctx[:e1].status_key = :transmitted
        @ctx[:j11].phase_key = :success
        @root.save!
        tengine.should_fire(:"start.job.job.tengine",
          :source_name => @ctx[:j12].name_as_resource,
          :properties => {
            :target_job_id => @ctx[:j12].id.to_s,
          }.update(@base_props))
        tengine.receive("success.job.job.tengine",
          :source_name => @ctx[:j11].name_as_resource,
          :properties => {
            :target_job_id => @ctx[:j11].id.to_s,
          }.update(@base_props))
        @root.reload
        @ctx.vertex(:j12).phase_key.should == :ready
        @ctx.edge(:e2).status_key.should == :transmitting
        @ctx.edge(:e3).status_key.should == :active
      end

      it "失敗した場合" do
        @root.phase_key = :running
        @ctx[:e1].status_key = :transmitted
        @ctx[:j11].phase_key = :error
        @root.save!
        tengine.should_fire(:"error.jobnet.job.tengine",
          :source_name => @root.name_as_resource,
          :properties => @base_props)
        tengine.receive("error.job.job.tengine", :properties => {
            :target_job_id => @ctx[:j11].id.to_s
          }.update(@base_props))
        @root.reload
        @ctx.vertex(:j11).phase_key.should == :error
        @ctx.vertex(:j12).phase_key.should == :initialized
        @ctx.edge(:e2).status_key.should == :closed
        @ctx.edge(:e3).status_key.should == :closed
        @root.phase_key.should == :error
        @root.finished_at.utc.iso8601.should == @now.utc.iso8601
      end
    end

    context 'j12を実行' do
      it "成功した場合" do
        @root.phase_key = :running
        @ctx[:e1].status_key = :transmitted
        @ctx[:e2].status_key = :transmitted
        @ctx[:j11].phase_key = :success
        @ctx[:j12].phase_key = :success
        @root.save!
        tengine.should_fire(:"success.jobnet.job.tengine",
          :source_name => @root.name_as_resource,
          :properties => @base_props)
        tengine.receive("success.job.job.tengine", :properties => {
            :target_job_id => @ctx[:j12].id.to_s
          }.update(@base_props))
        @root.reload
        @ctx.edge(:e3).status_key.should == :transmitted
        @root.phase_key.should == :success
        @root.finished_at.utc.iso8601.should == @now.utc.iso8601
      end

      it "失敗した場合" do
        @root.phase_key = :running
        @ctx[:e1].status_key = :transmitted
        @ctx[:e2].status_key = :transmitted
        @ctx[:j11].phase_key = :success
        @ctx[:j12].phase_key = :error
        @root.save!
        tengine.should_fire(:"error.jobnet.job.tengine",
          :source_name => @root.name_as_resource,
          :properties => @base_props)
        tengine.receive("error.job.job.tengine", :properties => {
            :target_job_id => @ctx[:j12].id.to_s
          }.update(@base_props))
        @root.reload
        @ctx.edge(:e3).status_key.should == :closed
        @root.phase_key.should == :error
        @root.finished_at.utc.iso8601.should == @now.utc.iso8601
      end
    end

  end

  # in [rjn0002]
  #              |--e2-->(j11)--e4-->|
  # (S1)--e1-->[F1]                [J1]--e6-->(E1)
  #              |--e3-->(j12)--e5-->|
  context "rjn0002" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0002SimpleParallelJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @base_props = {
        :execution_id => @execution.id.to_s,
        :root_jobnet_id => @root.id.to_s,
        :target_jobnet_id => @root.id.to_s,
      }
    end

    it "最初のリクエスト" do
      [:e1, :e2, :e3, :e4, :e5, :e6].each{|name| @ctx[name].status_key = :active}
      @root.phase_key = :ready
      @root.save!
      tengine.should_fire(:"start.job.job.tengine",
        :source_name => @ctx.vertex(:j11).name_as_resource,
        :properties => {
          :target_job_id => @ctx[:j11].id.to_s,
        }.update(@base_props))
      tengine.should_fire(:"start.job.job.tengine",
        :source_name => @ctx.vertex(:j12).name_as_resource,
        :properties => {
          :target_job_id => @ctx[:j12].id.to_s,
        }.update(@base_props))
      tengine.receive("start.jobnet.job.tengine", :properties => @base_props)
      @root.reload
      @root.phase_key.should == :running
      @root.started_at.utc.iso8601.should == @now.utc.iso8601
      @ctx.vertex(:j11).phase_key.should == :ready
      @ctx.vertex(:j12).phase_key.should == :ready
      @ctx.edge(:e1).status_key.should == :transmitted
      @ctx.edge(:e2).status_key.should == :transmitting
      @ctx.edge(:e3).status_key.should == :transmitting
      @ctx.edge(:e4).status_key.should == :active
      @ctx.edge(:e5).status_key.should == :active
      @ctx.edge(:e6).status_key.should == :active
    end

    context 'j11を実行' do
      before do
        @root.phase_key = :running
        # j12は実行中
        @ctx[:e1].status_key = :transmitted
        @ctx[:e2].status_key = :transmitted
        @ctx[:e3].status_key = :transmitted
        @ctx[:j11].phase_key = :running
        @ctx[:j12].phase_key = :running
        @root.save!
      end

      it "成功した場合" do
        @ctx[:j11].phase_key = :success
        @root.save!
        tengine.should_not_fire
        tengine.receive("success.job.job.tengine", :properties => {
            :target_job_id => @ctx[:j11].id.to_s,
          }.update(@base_props))
        @root.reload
        @ctx.vertex(:j12).phase_key.should == :running
        @ctx.edge(:e4).status_key.should == :transmitted
        @ctx.edge(:e5).status_key.should == :active
        @ctx.edge(:e6).status_key.should == :active
      end

      it "失敗した場合" do
        @ctx[:j11].phase_key = :error
        @root.save!
        tengine.should_not_fire
        tengine.receive("error.job.job.tengine", :properties => {
            :target_job_id => @ctx[:j11].id.to_s
          }.update(@base_props))
        @root.reload
        @ctx.vertex(:j12).phase_key.should == :running
        @ctx.edge(:e4).status_key.should == :closed
        @ctx.edge(:e5).status_key.should == :active
        @ctx.edge(:e6).status_key.should == :closed
      end
    end

    context 'j12を実行' do
      context "j11は成功した場合" do
        before do
          @root.phase_key = :running
          @ctx[:e1].status_key = :transmitted
          @ctx[:e2].status_key = :transmitted
          @ctx[:e3].status_key = :transmitted
          @ctx[:e4].status_key = :transmitted
          @ctx[:j11].phase_key = :success
          @ctx[:j12].phase_key = :running
          @root.save!
        end

        it "成功した場合" do
          @ctx[:j12].phase_key = :success
          @root.save!
          tengine.should_fire(:"success.jobnet.job.tengine",
            :source_name => @root.name_as_resource,
            :properties => @base_props)
          tengine.receive("success.job.job.tengine", :properties => {
              :target_job_id => @ctx[:j12].id.to_s,
            }.update(@base_props))
          @root.reload
          @root.phase_key.should == :success
          @root.finished_at.utc.iso8601.should == @now.utc.iso8601
          @ctx.edge(:e5).status_key.should == :transmitted
          @ctx.edge(:e6).status_key.should == :transmitted
        end

        it "失敗した場合" do
          @ctx[:j12].phase_key = :error
          @root.save!
          tengine.should_fire(:"error.jobnet.job.tengine",
            :source_name => @root.name_as_resource,
            :properties => @base_props)
          tengine.receive("error.job.job.tengine", :properties => {
              :target_job_id => @ctx[:j12].id.to_s
            }.update(@base_props))
          @root.reload
          @root.phase_key.should == :error
          @root.finished_at.utc.iso8601.should == @now.utc.iso8601
          @ctx.edge(:e5).status_key.should == :closed
          @ctx.edge(:e6).status_key.should == :closed
        end
      end

      context "j11は失敗した場合" do
        before do
          @root.phase_key = :running
          @ctx[:e1].status_key = :transmitted
          @ctx[:e2].status_key = :transmitted
          @ctx[:e3].status_key = :transmitted
          @ctx[:e4].status_key = :closed
          @ctx[:e5].status_key = :active
          @ctx[:e6].status_key = :closed
          @ctx[:j11].phase_key = :error
          @ctx[:j12].phase_key = :running
          @root.save!
        end

        it "成功した場合" do
          @ctx[:j12].phase_key = :success
          @root.save!
          tengine.should_fire(:"error.jobnet.job.tengine",
            :source_name => @root.name_as_resource,
            :properties => @base_props)
          tengine.receive("success.job.job.tengine", :properties => {
              :target_job_id => @ctx[:j12].id.to_s,
            }.update(@base_props))
          @root.reload
          @root.phase_key.should == :error
          @root.finished_at.utc.iso8601.should == @now.utc.iso8601
          @ctx.edge(:e5).status_key.should == :transmitted
          @ctx.edge(:e6).status_key.should == :closed
        end


        it "失敗した場合" do
          @ctx[:j12].phase_key = :error
          @root.save!
          tengine.should_fire(:"error.jobnet.job.tengine",
            :source_name => @root.name_as_resource,
            :properties => @base_props)
          tengine.receive("error.job.job.tengine", :properties => {
              :target_job_id => @ctx[:j12].id.to_s
            }.update(@base_props))
          @root.reload
          @root.phase_key.should == :error
          @root.finished_at.utc.iso8601.should == @now.utc.iso8601
          @ctx.edge(:e5).status_key.should == :closed
          @ctx.edge(:e6).status_key.should == :closed
        end
      end
    end

  end

  # in [rjn0005]
  #              |-----e2----->(j11)-----e4----->|
  # [S1]--e1-->[F1]                            [J1]--e7-->[E1]
  #              |--e3-->(j12)--e5-->(j13)--e6-->|
  context "rjn0005" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn00052jobsAnd1jobParallelJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @base_props = {
        :execution_id => @execution.id.to_s,
        :root_jobnet_id => @root.id.to_s,
        :target_jobnet_id => @root.id.to_s,
      }
    end

    # j11, j12の実行は Rjn0002SimpleParallelJobnetBuilder と同じなので省略。

    # j11が失敗した際に、タイミングが悪くj12からj13へ処理が遷移する瞬間で、
    # j10にはactiveなvertexがない状態になった場合でも、j13が実行されてから
    # j10のfinished.jobnet.job.tengineイベントが発火されなければならない。

    # 動作としては j11が失敗すると、j11からE1までの間のe4とe7をclosedにする。
    # その後j12が終了すると、e5はclosedされていないので、transmitされてj13が動く。
    # その後j13が実行された後、e6をtransmitした際に、j10の全てのedgeがactiveで
    # なくなるので、j10は終了したと見なされる。

    context 'j11が失敗' do
      context "j12が同時に成功" do
        before do
          @root.phase_key = :running
          @ctx[:e1].status_key = :transmitted
          @ctx[:e2].status_key = :transmitted
          @ctx[:e3].status_key = :transmitted
          @ctx[:j11].phase_key = :running
          @ctx[:j12].phase_key = :running
          @ctx[:j13].phase_key = :ready
          @root.save!
        end

        it do
          # j12が成功したという、finished.job.job.tengineイベントが投げられて、j13のstart.job.job.tengineが受信されるまでの間に、
          @ctx[:j12].phase_key = :success
          @ctx[:e5].status_key = :active
          # j11が失敗したという finished.job.job.tengineイベントが受信された場合
          @ctx[:j11].phase_key = :error
          @root.save!
          tengine.should_not_fire # j13が動いていないので、e5,e6はactiveなので、ジョブネットは終了しません。
          tengine.receive("error.job.job.tengine", :properties => {
              :target_job_id => @ctx[:j11].id.to_s,
            }.update(@base_props))
          @root.reload
          @root.phase_key.should == :running
          @root.finished_at.should == nil
          @ctx.edge(:e4).status_key.should == :closed
          @ctx.edge(:e5).status_key.should == :active
          @ctx.edge(:e6).status_key.should == :active
          @ctx.edge(:e7).status_key.should == :closed
        end
      end

    end

  end

end
