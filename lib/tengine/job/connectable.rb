# -*- coding: utf-8 -*-
require 'tengine/job'

module Tengine::Job::Connectable
  extend ActiveSupport::Concern

  included do
    field :server_name    , :type => String # 接続先となるサーバ名。Tengine::Resource::Server#name を指定します
    field :credential_name, :type => String # 接続時に必要な認証情報。Tengine::Resource::Credential#name を指定します

    include Tengine::Job::MmCompatibility::Connectable

    def actual_credential_name
      credential_name || (parent ? parent.actual_credential_name : nil)
    end

    def actual_server_name
      server_name || (parent ? parent.actual_server_name : nil)
    end


  end
end
