# -*- coding: utf-8 -*-
require 'tengine/job'
require 'selectable_attr'

# ジョブ／ジョブネットを実行する際の情報に関するモジュール
# Tengine::Job::JobnetActual, Tengine::Job::JobnetTemplateがこのモジュールをincludeします
module Tengine::Job::Executable
  extend ActiveSupport::Concern

  included do
    field :phase_cd   , :type => Integer  # 進行状況。とりうる値は以下を参照してください。詳しくは「tengine_jobパッケージ設計書」の「ジョブ／ジョブネット状態遷移」を参照してください
    field :started_at , :type => DateTime # 開始時刻。
    field :finished_at, :type => DateTime # 終了時刻。強制終了時にも設定されます。
    field :stopped_at , :type => DateTime # 停止時刻。停止を開始した時刻です。
    field :stop_reason, :type => String   # 停止理由。手動以外での停止ならば停止した理由が設定されます。

    include SelectableAttr::Base
    selectable_attr :phase_cd do
      entry  0, :ready     , "ready"
      entry 20, :starting  , "starting"
      entry 21, :running   , "running"
      entry 30, :dying     , "dying"
      entry 10, :success   , "success"
      entry 40, :error     , "error"
      entry 50, :stuck     , "stuck"
    end
  end

end
