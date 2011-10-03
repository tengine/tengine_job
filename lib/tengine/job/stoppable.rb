# -*- coding: utf-8 -*-
require 'tengine/job'

# 終了対象となりうるVertexで使用するモジュール
module Tengine::Job::Stoppable
  extend ActiveSupport::Concern

  included do
    field :killing_signals, :type => Array # 強制停止時にプロセスに送るシグナルの配列
    array_text_accessor :killing_signals

    field :killing_signal_interval, :type => Integer # 強制停止時にkilling_signalsで定義されるシグナルを順次送信する間隔。
  end
end
