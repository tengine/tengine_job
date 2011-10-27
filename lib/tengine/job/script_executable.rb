# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブとして実際にスクリプトを実行する処理をまとめるモジュール。
# Tengine::Job::JobnetActualと、Tengine::Job::ScriptActualがincludeします
module Tengine::Job::ScriptExecutable
  extend ActiveSupport::Concern

  included do
    field :executing_pid, :type => String # 実行しているプロセスのPID
    field :exit_status  , :type => String # 終了したプロセスが返した終了ステータス
  end

  def run(execution)
    return ack(@acked_pid) if @acked_pid
    cmd = build_command(execution)
    # puts "cmd:\n" << cmd
    execute(cmd)
  end

  def execute(cmd)
    Tengine.logger.info("connecting to #{actual_server.hostname_or_ipv4}")
    actual_credential.connect(actual_server.hostname_or_ipv4) do |ssh|
      # see http://net-ssh.github.com/ssh/v2/api/classes/Net/SSH/Connection/Channel.html
      ssh.open_channel do |channel|
        Tengine.logger.info("now exec on ssh: " << cmd)
        channel.exec(cmd) do |ch, success|
          abort "could not execute command" unless success

          channel.on_data do |ch, data|
            Tengine.logger.debug("got stdout: #{data}")
            # puts "on_data: #{data.inspect}"
            ack(data.strip)
          end

          channel.on_extended_data do |ch, type, data|
            Tengine.logger.warn("got stderr: #{data}")
          end

          channel.on_close do |ch|
            # puts "channel is closing!"
          end
        end
      end

    end
  end

  def kill(execution)
    lines = source_profiles
    cmd = executable_command("tengine_job_agent_kill %s --signals=%s --interval=%d" % [
        self.executing_pid,
        self.actual_killing_signals.join(","),
        self.actual_killing_signal_interval
      ])
    lines << cmd
    cmd = lines.join(' && ')
    execute(cmd)
  end

#   def ack(pid)
#     @acked_pid = pid
#     self.executing_pid = pid
#     self.phase_key = :running
#     self.previous_edges.each{|edge| edge.status_key = :transmitted}
#   end

  def build_command(execution)
    result = source_profiles
    mm_env = build_mm_env(execution).map{|k,v| "#{k}=#{v}"}.join(" ")
    # Hadoopジョブの場合は環境変数をセットする
    if is_a?(Tengine::Job::Jobnet) && (jobnet_type_key == :hadoop_job_run)
      mm_env << ' ' << hadoop_job_env
    end
    result << "export #{mm_env}"
    unless execution.preparation_command.blank?
      result << execution.preparation_command
    end
    # cmdはユーザーが設定したスクリプトを組み立てたもので、
    # プロセスの監視／強制停止のためにtengine_job_agent/bin/tengine_job_agent_run
    # からこれらを実行させるためにはcmdを編集します。
    # tengine_job_agent_runは、標準出力に監視対象となる起動したプロセスのPIDを出力します。
    runner_path = ENV["MM_RUNNER_PATH"] || executable_command("tengine_job_agent_run")
    runner_option = ""
    # 実装するべきか要検討
    # runner_option << " --stdout" if execution.keeping_stdout
    # runner_option << " --stderr" if execution.keeping_stderr
    # script = "#{runner_path}#{runner_option} -- #{self.script}" # runnerのオプションを指定する際は -- の前に設定してください
    script = "#{runner_path}#{runner_option} #{self.script}" # runnerのオプションを指定する際は -- の前に設定してください
    result << script
    result.join(" && ")
  end

  def source_profiles
    # RubyのNet::SSHでは設定ファイルが読み込まれないので、ロードするようにします。
    # ~/.bash_profile, ~/.bashrc などは非対応。
    # ファイルが存在していたらsourceで読み込むようにしたいのですが、一旦保留します。
    # http://www.syns.net/10/
    ["/etc/profile", "/etc/bashrc", "$HOME/.bashrc", "$HOME/.bash_profile"].map do |path|
      "if [ -f #{path} ]; then source #{path}; fi"
    end
  end

  def executable_command(command)
    if prefix = ENV["MM_CMD_PREFIX"]
      "#{prefix} #{command}"
    else
      command
    end
  end

  # MMから実行されるシェルスクリプトに渡す環境変数のHashを返します。
  # MM_ACTUAL_JOB_ID                : 実行される末端のジョブのMM上でのID
  # MM_ACTUAL_JOB_ANCESTOR_IDS      : 実行される末端のジョブの祖先のMM上でのIDをセミコロンで繋げた文字列 (テンプレートジョブ単位)
  # MM_FULL_ACTUAL_JOB_ANCESTOR_IDS : 実行される末端のジョブの祖先のMM上でのIDをセミコロンで繋げた文字列 (expansionから展開した単位)
  # MM_ACTUAL_JOB_NAME_PATH         : 実行される末端のジョブのname_path
  # MM_ACTUAL_JOB_SECURITY_TOKEN    : 公開API呼び出しのためのセキュリティ用のワンタイムトークン
  # MM_TEMPLATE_JOB_ID              : テンプレートジョブ(=実行される末端のジョブの元となったジョブ)のID
  # MM_TEMPLATE_JOB_ANCESTOR_IDS    : テンプレートジョブの祖先のMM上でのIDをセミコロンで繋げたもの
  # MM_SCHEDULE_ID                  : 実行スケジュールのID
  # MM_SCHEDULE_ESTIMATED_TIME      : 実行スケジュールの見積り時間。単位は分。
  # MM_SCHEDULE_ESTIMATED_END       : 実行スケジュールの見積り終了時刻をYYYYMMDDHHMMSS式で。(できればISO 8601など、タイムゾーンも表現できる標準的な形式の方が良い？)
  # MM_MASTER_SCHEDULE_ID           : マスタースケジュールがあればそのID。マスタースケジュールがない場合は環境変数は指定されません。
  #
  # 未実装
  # MM_FAILED_JOB_ID                : ジョブが失敗した場合にrecoverやfinally内のジョブを実行時に設定される、失敗したジョブのMM上でのID。
  # MM_FAILED_JOB_ANCESTOR_IDS      : ジョブが失敗した場合にrecoverやfinally内のジョブを実行時に設定される、失敗したジョブの祖先のMM上でのIDをセミコロンで繋げた文字列。
  def build_mm_env(execution)
    result = {
      "MM_ROOT_JOBNET_ID" => root.id.to_s,
      "MM_TARGET_JOBNET_ID" => parent.id.to_s,
      "MM_ACTUAL_JOB_ID" => id.to_s,
      "MM_ACTUAL_JOB_ANCESTOR_IDS" => '"%s"' % ancestors_until_expansion.map(&:id).map(&:to_s).join(';'),
      "MM_FULL_ACTUAL_JOB_ANCESTOR_IDS" => '"%s"' % ancestors.map(&:id).map(&:to_s).join(';'),
      "MM_ACTUAL_JOB_NAME_PATH" => name_path.dump,
      "MM_ACTUAL_JOB_SECURITY_TOKEN" => "", # TODO トークンの生成
      "MM_SCHEDULE_ID" => execution.id.to_s,
      "MM_SCHEDULE_ESTIMATED_TIME" => execution.estimated_time,
    }
    if estimated_end = execution.actual_estimated_end
      result["MM_SCHEDULE_ESTIMATED_END"] = estimated_end.strftime("%Y%m%d%H%M%S")
    end
    if rjt = root.template
      t = rjt.find_descendant_by_name_path(self.name_path)
      result.update({
          "MM_TEMPLATE_JOB_ID" => t.id.to_s,
          "MM_TEMPLATE_JOB_ANCESTOR_IDS" => '"%s"' % t.ancestors.map(&:id).map(&:to_s).join(';'),
      })
    end
    # if ms = execution.master_schedule
    #   result.update({
    #       "MM_MASTER_SCHEDULE_ID" => ms.id.to_s,
    #   })
    # end
    result
  end

  def hadoop_job_env
    s = children.select{|c| c.is_a?(Tengine::Job::Jobnet) && (c.jobnet_type_key == :hadoop_job)}.
      map{|c| "#{c.name}\\t#{c.id.to_s}\\n"}.join
    "MM_HADOOP_JOBS=\"#{s}\""
  end


end
