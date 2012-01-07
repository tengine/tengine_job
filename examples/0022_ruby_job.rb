# -*- coding: utf-8 -*-
require 'tengine_job'

jobnet("rjn0022") do
  boot_jobs('j1')
  ruby_job('j1', :to => ['j2', 'j3']){ STDOUT.puts("j1") }
  ruby_job('j2', :to => 'j4'        ){ STDOUT.puts("j2") }
  ruby_job('j3', :to => 'j4'        ){ STDOUT.puts("j3") }
  ruby_job('j4'                     ){ STDOUT.puts("j4") }
end
