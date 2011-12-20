require 'tengine_job'

jobnet("rjn0020", :server_name => "test_server1", :credential_name => "test_credential1") do
  auto_sequence
  job("j1", "env | sort", :preparation => proc{ "export FOO=BAR" })
  job("j2", "env | sort", :preparation => proc{ "export SERVER_NAME=#{actual_server.name} && export DNS_NAME=#{actual_server.addresses['private_dns_name']}" })
end
