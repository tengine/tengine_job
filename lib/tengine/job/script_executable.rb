# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブとして実際にスクリプトを実行する処理をまとめるモジュール。
# Tengine::Job::JobnetActualと、Tengine::Job::ScriptActualがincludeします
module Tengine::Job::ScriptExecutable
  def run(execution)
    pid = execute(execution)
    # ack(pid)
  end

  def execute(execution)
    cmd = build_command(execution)
  end

  def build_command(execution)
    result = []
    # RubyのNet::SSHでは設定ファイルが読み込まれないので、ロードするようにします。
    # ~/.bash_profile, ~/.bashrc などは非対応。
    # ファイルが存在していたらsourceで読み込むようにしたいのですが、一旦保留します。
    # http://www.syns.net/10/
    result << "source /etc/profile"
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
    runner_path = ENV["MM_RUNNER_PATH"] || "tengine_job_agent_run"
    runner_option = ""
    # 実装するべきか要検討
    # runner_option << " --stdout" if execution.keeping_stdout
    # runner_option << " --stderr" if execution.keeping_stderr
    script = "#{runner_path}#{runner_option} -- #{self.script}" # runnerのオプションを指定する際は -- の前に設定してください
    result << script
    result.join(" && ")
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
      "MM_ACTUAL_JOB_ID" => id.to_s,
      "MM_ACTUAL_JOB_ANCESTOR_IDS" => '"%s"' % ancestors_until_expansion.map(&:id).map(&:to_s).join(';'),
      "MM_FULL_ACTUAL_JOB_ANCESTOR_IDS" => '"%s"' % ancestors.map(&:id).map(&:to_s).join(';'),
      "MM_ACTUAL_JOB_NAME_PATH" => name_path.dump,
      "MM_ACTUAL_JOB_SECURITY_TOKEN" => "", # TODO トークンの生成
      "MM_SCHEDULE_ID" => execution.id.to_s,
      "MM_SCHEDULE_ESTIMATED_TIME" => execution.estimated_time,
    }
    if estimated_end = execution.actual_estimated_end
      result["MM_SCHEDULE_ESTIMATED_END"] = execution.actual_estimated_end.strftime("%Y%m%d%H%M%S")
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
