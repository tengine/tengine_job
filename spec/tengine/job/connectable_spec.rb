# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Job::Connectable do

  context "Rjn0001SimpleJobnetBuilderを使う場合" do
    [:actual, :template].each do |jobnet_type|
      context "#{jobnet_type}の場合" do

        before(:all) do
          builder = Rjn0004TreeSequentialJobnetBuilder.new
          builder.send(:"create_#{jobnet_type}")
          @ctx = builder.context
        end

        {
          "rjn0004" => [nil, nil],
          "j1100" => ["goku_ssh_pw" , "hadoop_master_node"],
          "j1110" => ["goku_ssh_pw" , "hadoop_master_node"],
          "j1120" => ["goku_ssh_pw" , "hadoop_master_node"],
          "j1200" => ["goku_ssh_pw" , nil                 ],
          "j1210" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1300" => [nil           , "mysql_master"      ],
          "j1310" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1400" => [nil           , nil                 ],
          "j1410" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1500" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1510" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1511" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1600" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1610" => ["goku_ssh_pw" , "mysql_master"      ],
          "j1611" => ["goku_ssh_pw" , "hadoop_master_node"],
          "j1612" => ["gohan_ssh_pk", "mysql_master"      ],
          "j1620" => ["goku_ssh_pw" , "hadoop_master_node"],
          "j1621" => ["goku_ssh_pw" , "hadoop_master_node"],
          "j1630" => ["gohan_ssh_pk", "mysql_master"      ],
          "j1631" => ["gohan_ssh_pk", "mysql_master"      ],
        }.each do |job_name, (credential_name, server_name)|
          context job_name do
            subject{ @ctx[job_name.to_sym] }
            its(:actual_credential_name){ should == credential_name }
            its(:actual_server_name){ should == server_name }
          end
        end

      end
    end

  end
end
