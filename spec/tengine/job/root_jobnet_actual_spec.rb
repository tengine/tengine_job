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
      @j11 = @root.element("j11")
    end

    context "基本" do
      it "lockされていなければ処理はそのまま実行される" do
        @root.release_lock
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
        Tengine::Job.stub(:test_harness).with(an_instance_of(Integer), "waiting_for_lock_released"){ Fiber.yield }

        f1.resume.should == :end
        f1_updated.should == true
      end

      it "lockされているとupdate_with_lockに渡された処理は動かない" do
        @root.acquire_lock(@j11)
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
        Tengine::Job.should_receive(:test_harness).with(1, "waiting_for_lock_released"){ Fiber.yield }

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

      it "lockされていない状態でupdate_with_lockが実行されたが、ブロックの実行が終わる前にロックされた" do
        @root.release_lock
        @root.version = 1
        @root.save!
        @root.reload
        @root.version.should == 1

        f1_block_called_count = 0
        f1 = Fiber.new do
          r = Tengine::Job::RootJobnetActual.find(@root.id)
          r.update_with_lock do
            f1_block_called_count += 1
            if f1_block_called_count == 1
              Fiber.yield
            end
          end
          :end
        end

        Tengine::Job.test_harness_clear

        f1.resume # 上記のFiber.yieldでとまるはず
        f1_block_called_count.should == 1
        @root.reload
        @root.version.should == 1

        @root.acquire_lock(@j11)
        @root.version = 2
        @root.save!

        10.times do |idx|
          Tengine::Job.should_receive(:test_harness).with(idx + 1, "waiting_for_lock_released").once{ Fiber.yield }
          # resumeすると、version違いでリトライされるが、
          # リトライ時に、lockされているかどうかのチェックを行うので、lockが解放されるまで進まない
          f1.resume.should_not == :end
          f1_block_called_count.should == 1
          @root.reload
          @root.version.should == 2
        end

        @root.release_lock
        @root.version = 3
        @root.save!

        f1.resume.should == :end
        @root.reload
        @root.version.should == 4
        f1_block_called_count.should == 2
      end

    end
  end


  context 'wait_to_acquire_lock' do
    before do
      Tengine::Job::Execution.delete_all
      Tengine::Job::Vertex.delete_all
      TestCredentialFixture.test_credential1
      TestServerFixture.test_server1
      builder = Rjn0002SimpleParallelJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @j11 = @root.element("j11")
    end

    context "基本" do
      it "lockされていなければ自身がロックを取得できる" do
        @root.release_lock
        @root.version = 1
        @root.save!

        @root.reload
        @root.version.should == 1
        @root.lock_key.should == ""
        Time.stub(:now).and_return(Time.local(2011,12,27,2,37))

        @root.wait_to_acquire_lock(@j11)

        @root.reload
        @root.version.should == 2
        @root.lock_key.should == "#{Process.pid.to_s}/#{@j11.id.to_s}"
        @root.lock_timeout_key.should == "#{Process.pid.to_s}/#{@j11.id.to_s}-2011-12-26T17:37:00Z"
        @root.locking_vertex_id.should == @j11.id.to_s
      end

      it "競合する場合は先勝ち。後者は解放されるまで待ちます" do
        @root.acquire_lock(@j11)
        @root.version = 1
        @root.save!
        @root.reload
        @root.version.should == 1

        f1 = Fiber.new do
          r = Tengine::Job::RootJobnetActual.find(@root.id)
          r.wait_to_acquire_lock(@root.element("j12"))
          :end
        end

        Tengine::Job.test_harness_clear
        10.times do |idx|
          Tengine::Job.should_receive(:test_harness).with(idx + 1, "wait_to_acquire_lock").once{ Fiber.yield }
          f1.resume.should_not == :end
          @root.reload
          @root.version.should == 1
        end

        @root.release_lock
        @root.version = 2
        @root.save!
        @root.reload
        @root.version.should == 2

        f1.resume.should == :end # 後者がロックを取得する

        @root.reload
        @root.version.should == 3
      end
    end

    context "ブロック付きの場合はちゃんと最後にロックを解放します" do
      before do
        @root.element("j11").tap{|j| j.phase_key = :initialized}
        @root.element("j12").tap{|j| j.phase_key = :initialized}
        @root.version = 1
        @root.save!
      end

      it "通常" do
        f1 = Fiber.new do
          r = Tengine::Job::RootJobnetActual.find(@root.id)
          r.wait_to_acquire_lock(r.element("j11")) do
            Fiber.yield
            j11 = r.element("j11")
            j11.phase_key = :ready
          end
          :end
        end

        f1.resume.should_not == :end
        @root.reload
        @root.version.should == 2
        @root.lock_key.should == "#{Process.pid.to_s}/#{@j11.id.to_s}"
        @root.lock_timeout_key.should =~ /^#{Regexp.escape(@root.lock_key)}-\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
        @root.locking_vertex_id.should == @j11.id.to_s

        f1.resume.should == :end
        @root.reload
        @root.version.should == 3
        @root.lock_key.should == ""
        @root.lock_timeout_key.should == nil
        @root.locking_vertex_id.should == nil
      end

      it "ブロック内で例外がraiseされた場合場合" do
        f1 = Fiber.new do
          r = Tengine::Job::RootJobnetActual.find(@root.id)
          r.wait_to_acquire_lock(r.element("j11")) do
            Fiber.yield
            raise "Some Runtime Error"
          end
          :end
        end

        f1.resume.should_not == :end
        @root.reload
        @root.version.should == 2
        @root.lock_key.should == "#{Process.pid.to_s}/#{@j11.id.to_s}"
        @root.lock_timeout_key.should =~ /^#{Regexp.escape(@root.lock_key)}-\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
        @root.locking_vertex_id.should == @j11.id.to_s

        expect{
          f1.resume
        }.to raise_error("Some Runtime Error")
        @root.reload
        @root.version.should == 3
        @root.lock_key.should == ""
        @root.lock_timeout_key.should == nil
        @root.locking_vertex_id.should == nil
      end

      it "競合した場合" do
        j12 = @root.element("j12")
        f1 = Fiber.new do
          r = Tengine::Job::RootJobnetActual.find(@root.id)
          r.wait_to_acquire_lock(r.element("j11")) do
            Fiber.yield
            j11 = r.element("j11")
            j11.phase_key = :ready
          end
          :end
        end

        f2 = Fiber.new do
          idx = 0
          r = Tengine::Job::RootJobnetActual.find(@root.id)
          r.wait_to_acquire_lock(r.element("j12")) do
            j12 = r.element("j12")
            j12.phase_key = :ready
            Fiber.yield
          end
          :end
        end

        Tengine::Job.test_harness_clear

        f1.resume.should_not == :end
        @root.reload
        @root.version.should == 2
        @root.lock_key.should == "#{Process.pid.to_s}/#{@j11.id.to_s}"
        @root.lock_timeout_key.should =~ /^#{Regexp.escape(@root.lock_key)}-\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
        @root.locking_vertex_id.should == @j11.id.to_s

        Tengine::Job.should_receive(:test_harness).with(1, "wait_to_acquire_lock").once{ Fiber.yield }
        f2.resume.should_not == :end
        @root.reload
        @root.version.should == 2
        @root.lock_key.should == "#{Process.pid.to_s}/#{@j11.id.to_s}"

        f1.resume.should == :end
        @root.reload
        @root.version.should == 3
        @root.lock_key.should == ""
        @root.lock_timeout_key.should == nil
        @root.locking_vertex_id.should == nil

        f2.resume.should_not == :end
        @root.reload
        @root.version.should == 4
        @root.lock_key.should == "#{Process.pid.to_s}/#{j12.id.to_s}"
        @root.lock_timeout_key.should =~ /^#{Regexp.escape(@root.lock_key)}-\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
        @root.locking_vertex_id.should == j12.id.to_s

        f2.resume.should == :end
        @root.reload
        @root.version.should == 5
        @root.lock_key.should == ""
        @root.lock_timeout_key.should == nil
        @root.locking_vertex_id.should == nil

      end
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
