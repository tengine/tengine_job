module TestServerFixture
  def test_server1
    Tengine::Resource::PhysicalServer.find_or_create_by(
      :name => "test_server1",
      :addresses => {
        :private_dns_name => "localhost"
      }
      )
  end

end
