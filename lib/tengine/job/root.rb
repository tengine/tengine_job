# -*- coding: utf-8 -*-
require 'tengine/job'

# ルートジョブネットとして必要な情報に関するモジュール
module Tengine::Job::Root
  extend ActiveSupport::Concern

  included do
    belongs_to :category, :inverse_of => :root_jobnet_templates, :index => true, :class_name => "Tengine::Job::Category"

    field :lock_version, :type => Integer, :default => 0 # ジョブネット全体を更新する際の楽観的ロックのためのバージョン。更新するたびにインクリメントされます。
  end
end
