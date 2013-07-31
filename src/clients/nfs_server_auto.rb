# encoding: utf-8

# File:
#   nfs_auto.ycp
#
# Package:
#   Configuration of NFS client
#
# Summary:
#   Client for autoinstallation
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param first a map of mail settings
# @return [Hash] edited settings or empty map if canceled
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallModule ("mail_auto", [ mm ]);
module Yast
  class NfsServerAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "nfs_server"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("NfsServer auto started")

      Yast.import "NfsServer"

      Yast.include self, "nfs_server/ui.rb"


      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Import Data
      if @func == "Import"
        @ret = NfsServer.Import(@param)
      # Create a  summary
      elsif @func == "Summary"
        @ret = NfsServer.Summary
      # Reset configuration
      elsif @func == "Reset"
        NfsServer.Import({})
        @ret = {}
      elsif @func == "Read"
        @ret = NfsServer.Read
      # Install required packages
      elsif @func == "Packages"
        @ret = NfsServer.AutoPackages
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = NfsServerAutoSequence()
      elsif @func == "GetModified"
        @ret = NfsServer.GetModified
      elsif @func == "SetModified"
        NfsServer.SetModified
      # Return actual state
      elsif @func == "Export"
        @ret = NfsServer.Export
      # Write givven settings
      elsif @func == "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        NfsServer.write_only = true
        @ret = NfsServer.Write
        Progress.set(@progress_orig)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("NfsServer auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::NfsServerAutoClient.new.main
