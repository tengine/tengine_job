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


  context 'フェーズロック付きupdate_with_lock' do
    before do
      Tengine::Job::Execution.delete_all
      Tengine::Job::Vertex.delete_all
      TestCredentialFixture.test_credential1
      TestServerFixture.test_server1
      builder = Rjn0002SimpleParallelJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
    end

    it "lockされているとupdate_with_lockに渡された処理は動かない" do
      j11 = @root.element("j11")
      @root.acquire_lock(j11)
      @root.version = 1
      @root.save!
      @root.reload
      @root.version.should == 1

      f1_updated = false
      f1 = Fiber.new do
        @root.update_with_lock do
          f1_updated = true
        end
        :end
      end

      Tengine::Job.test_harness_clear
      Tengine::Job.should_receive(:test_harness).with(1, "waiting_for_lock_released")

      f1.resume
      f1_updated.should == false

      r = Tengine::Job::RootJobnetActual.find(@root.id)
      r.release_lock
      r.version = 2
      r.save!

      f1.resume.should == :end
      f1_updated.should == true
      @root.reload
      @root.version.should == 3
    end

  end

  describe :rerun do
    before do
      Tengine::Job::Execution.delete_all
      Tengine::Job::Vertex.delete_all
      builder = Rjn0001SimpleJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @root.phase_key = :error
      @ctx[:e1].phase_key = :transmitted
      @ctx[:j11].phase_key = :success
      @ctx[:e2].phase_key = :transmitted
      @ctx[:j12].phase_key = :error
      @ctx[:e3].phase_key = :active
      @root.save!
      @execution.phase_key = :error
      @execution.save!
    end

    context "rerunするとExecutionが別に作られて、それを実行するイベントが発火される" do
      [true, false].each do |spot|

        it "スポット実行 #{spot.inspect}" do
          execution1 = Tengine::Job::Execution.new(:retry => true, :spot => spot,
            :root_jobnet_id => @root.id,
            :target_actual_ids => [@ctx[:j12].id])
          Tengine::Job::Execution.should_receive(:new).with({
              :retry => true, :spot => spot,
              :root_jobnet_id => @root.id
            }).and_return(execution1)
          sender = mock(:sender)
          sender.should_receive(:wait_for_connection).and_yield
          sender.should_receive(:fire).with(:'start.execution.job.tengine',
            :properties => {
              :execution_id => execution1.id.to_s,
            })
          expect{
            execution = @root.rerun(@ctx[:j12].id, :spot => spot, :sender => sender)
            execution.id.should_not == @execution.id # rerunの戻り値のexecutionは元々のexecutionとは別物です
          }.to change(Tengine::Job::Execution, :count).by(1)
        end
      end

    end

  end

end
