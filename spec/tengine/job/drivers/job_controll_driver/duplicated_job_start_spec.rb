# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

require 'net/ssh'


# 背景
# 以下の２つの条件が満たされ場合
#  * ２つのtenginedプロセスが動いている
#  * 並列で実行されるジョブを持つジョブネットが実行される(例えばrjn0002)
#
# 問題の詳細
# プロセス1がstart.job.job.tengineイベントによって起動したj11のプロセスのPIDを得る前に、
# プロセス2がstart.job.job.tengineイベントによってj12を起動することで、それらのルートジョブネットの
# versionが更新されてしまい、j11のPIDを得てルートジョブネットを更新する際にversionが
# 異なってしまっているため、update_with_lockメソッドによって実行に失敗したものと見なされて、
# 再度update_with_lockのブロックが実行されて、j11のプロセスが実行されてしまう。
#
# 本来どうあるべきか？
# versionによる楽観的ロックによる排他制御(とリトライ)を行うためには、
# 一つのルートジョブネットについて、SSH接続を行ってPIDを取得するまで処理を行っているジョブ
# (= phase_key が :starting となっているジョブ)が一つある場合は、それ以外のジョブ/ジョブネットは
# versionを更新するような処理を行うべきではない。つまり、update_with_lockを実行する前に
# 処理を進めても良いかどうかの確認を行う必要がある。
#
describe "<BUG>tengindのプロセスを二つ起動した際に並列ジョブがある際にジョブが２度実行される" do
  include Tengine::RSpec::Extension

  driver_path = File.expand_path("../../../../../lib/tengine/job/drivers/job_control_driver.rb", File.dirname(__FILE__))

  before do
    Tengine.logger.debug("=" * 100)
    Tengine.logger.debug("=" * 100)
    Tengine.logger.debug("=" * 100)
  end

  after do
    Tengine.logger.debug("-" * 100)
    Tengine.logger.debug("-" * 100)
    Tengine.logger.debug("-" * 100)
  end

  # in [rjn0002]
  #              |--e2-->(j11)--e4-->|
  # (S1)--e1-->[F1]                [J1]--e6-->(E1)
  #              |--e3-->(j12)--e5-->|
  context "rjn0002" do
    before do
      Tengine::Job::Execution.delete_all
      Tengine::Job::Vertex.delete_all
      TestCredentialFixture.test_credential1
      TestServerFixture.test_server1
      builder = Rjn0002SimpleParallelJobnetBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @base_props = {
        :execution_id => @execution.id.to_s,
        :root_jobnet_id => @root.id.to_s,
        :root_jobnet_name_path => @root.name_path,
        :target_jobnet_id => @root.id.to_s,
        :target_jobnet_name_path => @root.name_path,
      }

      # 2つのプロセスの代わりに、2つのカーネルを別のFiberで動かす
      @bootstrap1 = Tengine::Core::Bootstrap.new(:tengined => { :load_path => driver_path })
      @bootstrap1.kernel.tap{|k| k.bind; k.evaluate}
      @tengine1 = Tengine::RSpec::ContextWrapper.new(@bootstrap1.kernel)
      #
      @bootstrap2 = Tengine::Core::Bootstrap.new(:tengined => { :load_path => driver_path })
      @bootstrap2.kernel.tap{|k| k.bind; k.evaluate}
      @tengine2 = Tengine::RSpec::ContextWrapper.new(@bootstrap2.kernel)
    end

    # job_control_driverでのstart.job.job.tengineの処理の概略以下の通りです
    #
    # 1. Tengine::Job::RootJobnetActual#update_with_lock
    # 1.1. ロックがないことを確認
    # 1.2. ジョブの状態を遷移
    # 2. Tengine::Job::RootJobnetActual#wait_to_acquire_lock
    # 2.1. ロックを取得
    # 2.2. プロセスの起動を開始
    # 2.3. 起動したプロセスのPIDを取得
    #
    # これを２つのプロセスで動かす場合にどのような順番があり得るかというと、2の処理は排他制御下にあるので、
    # 以下のようなパターンがあり得ます
    #
    # パターン1 (ほぼ同時に2に突入する)
    #  A-1.1.
    #  A-1.2.
    #  B-1.1.
    #  B-1.2.
    #  A-2.1.
    #  B-2.1. 1st
    #  A-2.2.
    #  B-2.1. 2nd
    #  A-2.3.
    #  B-2.1. 3rd
    #  B-2.2.
    #  B-2.3.
    #
    # パターン2 (A-2.1. のにBが動き出す)
    #  A-1.1.
    #  A-1.2.
    #  B-1.1.
    #  A-2.1.
    #  B-1.2. 1st
    #  A-2.2.
    #  B-1.2. 2nd
    #  A-2.3.
    #  B-1.2. 3rd
    #  B-2.
    #
    # パターン3 (A-2.2. のにBが動き出す)
    #  A-1.1.
    #  A-1.2.
    #  A-2.1.
    #  B-1.1. 1st
    #  A-2.2.
    #  B-1.1. 2nd
    #  A-2.3.
    #  B-1.1. 3rd
    #  B-1.2.
    #  B-2.
    #
    # パターン4 (A-2.3. のにBが動き出す)
    #  A-1.1.
    #  A-1.2.
    #  A-2.1.
    #  A-2.2.
    #  B-1.1. 1st
    #  A-2.3.
    #  B-1.1. 2nd
    #  B-1.2.
    #  B-2.

    it "tengine1が起動したプロセスのPIDを得る前にtengine2がプロセスを起動することはできない" do
      @ctx[:e1].phase_key = :transmitted
      @ctx[:e2].phase_key = :transmitting
      @ctx[:e3].phase_key = :transmitting
      @ctx[:j11].phase_key = :ready
      @ctx[:j12].phase_key = :ready
      @root.phase_key = :starting
      @root.version = 1
      @root.save!

      pid1 = "111"
      f1 = Fiber.new do
        Process.stub(:pid).and_return(pid1)
        ssh1 = mock(:ssh1)
        Net::SSH.stub(:start).with(any_args).and_yield(ssh1)
        channel1 = mock(:channel1)
        ssh1.stub(:open_channel).and_yield(channel1)
        channel1.stub(:exec).with(any_args).and_yield(channel1, true)
        channel1.stub(:on_close) do
          Tengine.logger.debug( ("!" * 100) << "\non_close: Fiber.yield #{Process.pid} #{__FILE__}##{__LINE__}")
          Fiber.yield
        end # on_dataが呼び出される前に止める
        channel1.should_receive(:on_data).and_yield(channel1, pid1)
        channel1.stub(:on_extended_data)
        @tengine1.receive("start.job.job.tengine", :properties => {
            :target_job_id => @ctx.vertex(:j11).id.to_s,
            :target_job_name_path => @ctx.vertex(:j11).name_path,
          }.update(@base_props))
      end

      pid2 = "222"
      f2 = Fiber.new do
        Process.stub(:pid).and_return(pid2)
        ssh2 = mock(:ssh2)
        Net::SSH.stub(:start).with(any_args).and_yield(ssh2)
        channel2 = mock(:channel2)
        ssh2.stub(:open_channel).and_yield(channel2)
        channel2.stub(:exec).with(any_args).and_yield(channel2, true)
        channel2.should_receive(:on_close) do
          Tengine.logger.debug( ("!" * 100) << "\non_close: Fiber.yield #{Process.pid} #{__FILE__}##{__LINE__}")
          Fiber.yield
        end # on_dataが呼び出される前に止める
        channel2.should_receive(:on_data).and_yield(channel2, pid2)
        channel2.stub(:on_extended_data)
        @tengine2.receive("start.job.job.tengine", :properties => {
            :target_job_id => @ctx.vertex(:j12).id.to_s,
            :target_job_name_path => @ctx.vertex(:j12).name_path,
          }.update(@base_props))
      end

      j11 = @root.element("j11")
      j12 = @root.element("j12")

      @root.reload
      @root.version.should == 1
      @root.lock_key.should == ""
      @root.locking_vertex_id.should be_nil
      @root.lock_timeout_key.should be_nil

      Tengine::Job.test_harness_clear

      Tengine::Job.should_receive(:test_harness).with(1, "before callback in start.job.job.tengine").once{ Fiber.yield }

      f1.resume # j11がreadyからstartingへ遷移する。SSH接続を開始する前。
      @root.reload
      @root.version.should == 2 # start.job.job.tengineの最初のupdate_with_lock+1。
      @root.lock_key.should == ""
      @root.locking_vertex_id.should == nil
      @root.lock_timeout_key.should be_nil
      @root.element("j11").phase_key.should == :starting
      @root.element("j12").phase_key.should == :ready

      f1.resume # SSH接続を開始する。PIDはまだ取得していない。
      @root.reload
      @root.version.should == 3 # wait_to_acquire_lockの最初のlock_keyの取得で+1。
      @root.lock_key.should == "#{pid1}/#{j11.id.to_s}"
      @root.locking_vertex_id.should == j11.id.to_s
      @root.lock_timeout_key.should_not be_nil
      @root.element("j11").phase_key.should == :starting
      @root.element("j12").phase_key.should == :ready

      Tengine::Job.should_receive(:test_harness).with(2, "waiting_for_lock_released").once{ Fiber.yield }
      f2.resume # j12がreadyからstartingへ遷移しようとする。j11がstartingになるのでSSH接続を開始できない。
      @root.reload
      @root.version.should == 3
      @root.lock_key.should == "#{pid1}/#{j11.id.to_s}"
      @root.locking_vertex_id.should == j11.id.to_s
      @root.lock_timeout_key.should_not be_nil
      @root.element("j11").phase_key.should == :starting
      @root.element("j12").phase_key.should == :ready

      f1.resume # wait_to_acquire_lockのブロックが終了して、j11がstartingからrunningへ遷移する。PIDを取得済み
      @root.reload
      @root.version.should == 4
      @root.lock_key.should == ""
      @root.locking_vertex_id.should be_nil
      @root.lock_timeout_key.should be_nil
      @root.element("j11").tap{|j| j.phase_key.should == :running; j.executing_pid.should == pid1 }
      @root.element("j12").tap{|j| j.phase_key.should == :ready }

      Tengine::Job.should_receive(:test_harness).with(3, "before callback in start.job.job.tengine").once{ Fiber.yield }
      f2.resume # j12についてのstart.job.job.tengineの最初のupdate_with_lock+1。readyからstartingへ遷移する。まだSSH接続を開始していない
      @root.reload
      @root.version.should == 5
      @root.lock_key.should == ""
      @root.locking_vertex_id.should == nil
      @root.lock_timeout_key.should be_nil
      @root.element("j11").tap{|j| j.phase_key.should == :running; j.executing_pid.should == pid1 }
      @root.element("j12").tap{|j| j.phase_key.should == :starting }

      f2.resume # j12のSSH接続を開始する。PIDはまだ取得していない
      @root.reload
      @root.version.should == 6
      @root.lock_key.should == "#{pid2}/#{j12.id.to_s}"
      @root.locking_vertex_id.should == j12.id.to_s
      @root.lock_timeout_key.should_not be_nil
      @root.element("j11").tap{|j| j.phase_key.should == :running; j.executing_pid.should == pid1 }
      @root.element("j12").tap{|j| j.phase_key.should == :starting }

      f2.resume # j12がstartingからrunningへ遷移する。PIDを取得済み
      @root.reload
      @root.version.should == 7
      @root.lock_key.should == ""
      @root.locking_vertex_id.should be_nil
      @root.lock_timeout_key.should be_nil
      @root.element("j11").tap{|j| j.phase_key.should == :running; j.executing_pid.should == pid1 }
      @root.element("j12").tap{|j| j.phase_key.should == :running; j.executing_pid.should == pid2 }
    end
  end
end
