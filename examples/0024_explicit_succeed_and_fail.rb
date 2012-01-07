# -*- coding: utf-8 -*-
require 'tengine_job'

jobnet("rjn0024") do
  boot_jobs(*%w[jn01 jn02 j10 j11 j12])

  jobnet("jn01") do
    boot_jobs(*%w[j01 j02 j03 j04 j05 j06])
    ruby_job('j01'){|job| STDOUT.puts("j01 end") } # 自動でjob.succeedされる
    ruby_job('j02'){|job| job.succeed(:message => "j02 success"); STDOUT.puts("j02 end") }
    ruby_job('j03'){|job| job.fail(:exception => RuntimeError.new("j03 raise exception")); STDOUT.puts("j03 end") }
    ruby_job('j04'){|job| job.fail(:message => "j04 failed"); STDOUT.puts("j04 end") }
    ruby_job('j05'){|job| job.fail; job.succeed; job.fail; STDOUT.puts("j05 end") } # 最後のjob.failによってerrorになる
    ruby_job('j06'){|job| job.succeed; job.fail; job.succeed; STDOUT.puts("j06 end") } # 最後のjob.succeedによってsuccessになる
  end

  # job.succeedを明示的に書いていないけど必要に応じて呼び出される
  conductor1 = lambda{|job| job.run}
  jobnet('jn02', :conductors => {:ruby_job => conductor1}) do
    boot_jobs(*%w[j07 j08 j09])
    ruby_job('j07'){|job| STDOUT.puts("j07 end") } # 自動でjob.succeedされる
    ruby_job('j08'){|job| job.succeed(:message => "j08 success") }
    ruby_job('j09'){|job| job.fail(:message => "j09 failed") }
  end

  # job.runが2回記述されているけど一度しか動かさない
  ruby_job('j10', :conductor => lambda{|job| job.run; job.run}){|job| STDOUT.puts("j10 end") }

  # conductorではjob.succeed の後に job.fail を実行するとsuccessに。
  ruby_job('j11', :conductor => lambda{|job| job.run; job.succeed; job.fail}){|job| STDOUT.puts("j11 end") }

  # conductorではjob.fail の後に job.succeed を実行するとerrorに。
  ruby_job('j12', :conductor => lambda{|job| job.run; job.fail; job.succeed}){|job| STDOUT.puts("j12 end") }
end
