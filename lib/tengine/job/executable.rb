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
    field :phase_cd   , :type => Integer, :default => 20 # 進行状況。とりうる値は以下を参照してください。詳しくは「tengine_jobパッケージ設計書」の「ジョブ／ジョブネット状態遷移」を参照してください
    field :started_at , :type => Time     # 開始時刻。以前はDateTimeでしたが、実績ベースの予定終了時刻の計算のためにTimeにしました
    field :finished_at, :type => Time     # 終了時刻。強制終了時にも設定されます。

    include Tengine::Core::SelectableAttr
    selectable_attr :phase_cd do
      entry 20, :initialized, 'initialized'
      entry 30, :ready      , "ready"
      entry 50, :starting   , "starting"
      entry 60, :running    , "running"
      entry 70, :dying      , "dying"
      entry 40, :success    , "success"
      entry 80, :error      , "error"
      entry 90, :stuck      , "stuck"
    end

    def phase_key=(phase_key)
      element_type = nil
      case self.class
      when Tengine::Job::Execution then element_type = "execution"
      when Tengine::Job::RootJobnetActual then element_type = "root_jobnet"
      when Tengine::Job::JobnetActual then element_type = self.script_executable? ? "job" :
        self.jobnet_type_key == :normal ?  "jobnet" : self.jobnet_type_name
      end
      Tengine.logger.debug("#{element_type} phase changed. <#{ self.id.to_s}> #{self.phase_name} -> #{ self.class.phase_name_by_key(phase_key)}")
      self.write_attribute(:phase_cd, self.class.phase_id_by_key(phase_key))
    end

  end

end
