#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DaemonControl.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/StdIoWrapper'
require 'taskjuggler/apps/Tj3Daemon'
require 'taskjuggler/apps/Tj3Client'

class TaskJuggler

  module DaemonControl

    include StdIoWrapper

    def startDaemon(config = '')
      (f = File.new('taskjuggler.rc', 'w')).write(<<"EOT"
_global:
  authKey: 'secret_key'
  port: 0
  _log:
    outputLevel: 3
    logLevel: 3
#{config}
EOT
                                                 )
      f.close

      if (pid = fork).nil?
        at_exit { exit! }
        $stdout.reopen('stdout.log', 'w')
        $stderr.reopen('stderr.log', 'w')
        res = stdIoWrapper do
          Tj3Daemon.new.main(%w( --silent ))
        end
        raise "Failed to start tj3d: #{res.stdErr}" if res.returnValue != 0
        exit!
      else
        # Wait for the daemon to get online.
        i = 0
        while !File.exists?('.tj3d.uri') && i < 10
          sleep 0.5
          i += 1
        end
        raise 'Daemon did not start properly' if i == 10
      end
      0
    end

    def stopDaemon
      res = stdIoWrapper do
        Tj3Client.new.main(%w( --silent --unsafe terminate ))
      end
      raise "tj3d termination failed: #{res.stdErr}" if res.returnValue != 0
      i = 0
      while File.exists?('.tj3d.uri') && i < 10
        sleep 0.5
        i += 1
      end
      raise "Daemon did not terminate properly" if i == 10
      # Cleanup file system again.
      %w( taskjuggler.rc stdout.log stderr.log ).each do |file|
        File.delete(file)
      end
    end

  end

end
