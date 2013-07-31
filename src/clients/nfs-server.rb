# encoding: utf-8

# Author:	Martin Vidner <mvidner@suse.cz>
# Summary:	Just a redirection
# $Id$
module Yast
  class NfsServerClient < Client
    def main
      @target = "nfs_server"
      WFM.CallFunction(@target, WFM.Args)
    end
  end
end

Yast::NfsServerClient.new.main
