require 'tengine_job'

jobnet("rjn0020", :server_name => "test_server1", :credential_name => "test_credential1") do
  auto_sequence
  job("j11", "env | sort", :preparation => proc{ "export FOO=BAR" })
  job("j12", "env | sort", :preparation => proc{ "export SERVER_NAME=#{actual_server.name}" })
end
