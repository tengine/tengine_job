# -*- coding: utf-8 -*-
require 'tengine_job'

jobnet("rjn0020_1", :server_name => "test_server1", :credential_name => "test_credential1") do
  auto_sequence
  job("j1", "env | sort", :preparation => proc{ "export FOO=BAR" })
  job("j2", "env | sort", :preparation => proc{ "export SERVER_NAME=#{actual_server.name} && export DNS_NAME=#{actual_server.addresses['private_dns_name']}" })
end

jobnet("rjn0020_2") do # :server_name, :credential_nameの指定なし
  auto_sequence
  job("j1", "env | sort", :preparation => proc{ "export FOO=BAR" })
  job("j2", "env | sort", :preparation => proc{ "export SERVER_NAME=#{actual_server.name} && export DNS_NAME=#{actual_server.addresses['private_dns_name']}" })
end

jobnet("rjn0020", :server_name => "test_server1", :credential_name => "test_credential1") do
  auto_sequence
  expansion("rjn0020_1")
  expansion("rjn0020_2")
end
