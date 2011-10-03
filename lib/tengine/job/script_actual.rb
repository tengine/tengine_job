# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブとして実際にスクリプトを実行するVertex。
class Tengine::Job::ScriptActual < Tengine::Job::Script
  include Tengine::Job::RuntimeAttrs

  field :executing_pid, :type => String # 実行しているプロセスのPID
  field :exit_status  , :type => String # 終了したプロセスが返した終了ステータス
end
