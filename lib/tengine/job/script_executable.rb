# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブとして実際にスクリプトを実行する処理をまとめるモジュール。
# Tengine::Job::JobnetActualと、Tengine::Job::ScriptActualがincludeします
module Tengine::Job::ScriptExecutable
  def run
    pid = execute
    # ack(pid)
  end

  def execute
    cmd = build_command
  end

  def build_command
  end

end
