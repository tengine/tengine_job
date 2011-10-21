# -*- coding: utf-8 -*-
require 'tengine/job'
require 'selectable_attr'

# ジョブ／ジョブネットを実行する際の情報に関するモジュール
# Tengine::Job::JobnetActual, Tengine::Job::JobnetTemplateがこのモジュールをincludeします
module Tengine::Job::Executable
  extend ActiveSupport::Concern

  class PhaseError < StandardError
  end

  included do
    field :phase_cd   , :type => Integer, :default => 0 # 進行状況。とりうる値は以下を参照してください。詳しくは「tengine_jobパッケージ設計書」の「ジョブ／ジョブネット状態遷移」を参照してください
    field :started_at , :type => Time     # 開始時刻。以前はDateTimeでしたが、実績ベースの予定終了時刻の計算のためにTimeにしました
    field :finished_at, :type => Time     # 終了時刻。強制終了時にも設定されます。

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
