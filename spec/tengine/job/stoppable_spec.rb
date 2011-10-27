# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::Stoppable do
  include TestCredentialFixture
  include TestServerFixture

  describe :stop do
    context "rjn0006" do
      before do
        builder = Rjn0006NestedForkJobnetBuilder.new
        @ctx = builder.context
        @root = builder.create_actual
        @ctx[:j1100].tap do |j|
          j.killing_signals = ["INT", "HUP", "QUIT", "KILL"]
          j.killing_signal_interval = 30
        end
        @execution = Tengine::Job::Execution.create!({
            :root_jobnet_id => @root.id,
          })
        @mock_event = mock(:event)
        @mock_event.stub!(:[]).with(:execution_id).and_return(@execution.id.to_s)
        @signal = Tengine::Job::Signal.new(@mock_event)
      end

      context "何も変更なし" do
        ([:dying, :success, :error, :stuck]).each do |phase_key|
          it "#{phase_key}の場合" do
            @ctx[:j1110].phase_key = phase_key
            expect{
              @ctx[:j1110].stop(@signal)
            }.to_not raise_error
            @ctx[:j1110].phase_key.should == phase_key
          end
        end

        (Tengine::Job::JobnetActual.phase_keys - [:running, :dying, :success, :error, :stuck]).each do |phase_key|
          it "#{phase_key}の場合" do
            @ctx[:j1110].phase_key = phase_key
            expect{
              @ctx[:j1110].stop(@signal)
            }.to raise_error(Tengine::Job::Executable::PhaseError, "job_stop not available on #{phase_key.inspect}")
          end
        end
      end

      it "j1121をstopするとSSHでtengine_job_agent_killを実行する" do
        @pid = "1234"
        mock_ssh = mock(:ssh)
        mock_channel = mock(:channel)
        Net::SSH.should_receive(:start).
          with(test_server1.hostname_or_ipv4,
          test_credential1.auth_values['username'],
          :password => test_credential1.auth_values['password']).and_yield(mock_ssh)
        mock_ssh.should_receive(:open_channel).and_yield(mock_channel)
        mock_channel.should_receive(:exec) do |*args|
          args.length.should == 1
          args.first.tap do |cmd|
            cmd.should =~ %r<source \/etc\/profile>
            cmd.should =~ /tengine_job_agent_kill #{@pid} --signals=INT,HUP,QUIT,KILL --interval=30/
          end
        end
        t = Time.now.utc
        @mock_event.should_receive(:occurred_at).and_return(t)
        @mock_event.should_receive(:[]).with(:stop_reason).and_return("test stopping")
        @ctx[:j1110].tap do |j|
          j.phase_key = :running
          j.executing_pid = @pid
          j.stop(@signal)
          j.stop_reason.should == "test stopping"
          j.stopped_at.to_time.iso8601.should == t.utc.iso8601
        end
      end

    end
  end
end
