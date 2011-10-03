# -*- coding: utf-8 -*-
require 'tengine/job'

module Tengine::Job::Connectable
  extend ActiveSupport::Concern

  included do
    field :server_name    , :type => String # 接続先となるサーバ名。Tengine::Resource::Server#name を指定します
    field :credential_name, :type => String # 接続時に必要な認証情報。Tengine::Resource::Credential#name を指定します

    include Tengine::Job::MmCompatibility::Connectable
  end
end
