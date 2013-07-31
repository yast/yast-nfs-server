# encoding: utf-8

# Module:
#   NFS server configuration
#
# Summary:
#   Testsuite
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class ReadwriteUnfsdClient < Client
    def main
      # testedfiles: NfsServer.ycp Service.ycp Report.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @I_READ = { "target" => { "size" => 0 } }
      @I_WRITE = {}
      @I_EXEC = { "target" => { "bash_output" => {} } }
      TESTSUITE_INIT([@I_READ, @I_WRITE, @I_EXEC], nil)

      Yast.import "NfsServer"
      Yast.import "Report"

      Report.DisplayErrors(false, 0)

      @service_on = { "start" => ["3", "5"], "stop" => ["3", "5"] }
      @service_off = { "start" => [], "stop" => [] }
      @exports = [
        { "allowed" => ["proj*.local.domain(rw)"], "mountpoint" => "/projects" },
        {
          "allowed"    => ["*.local.domain(ro)", "@trusted(rw)"],
          "mountpoint" => "/usr"
        },
        { "allowed" => ["(ro,insecure,all_squash)"], "mountpoint" => "/pub" }
      ]
      @READ = {
        # Runlevel:
        "init"   => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => {
              "rpcbind"        => @service_on,
              "nfsserver"      => @service_on,
              "network"        => @service_on,
              "networkmanager" => @service_off
            },
            # their contents is not important for ServiceAdjust
            "comment"  => {
              "rpcbind"   => {},
              "nfsserver" => {}
            }
          }
        },
        # 	// targetpkg:
        # 	"targetpkg": $[
        # 	    // autofs
        # 	    "installed": true,
        # 	    ],
        # NfsServer itself:
        "etc"    => {
          "exports"   => @exports,
          "sysconfig" => {}
        },
        "target" => {
          "dir"  => nil,
          # pretend none exist
          "stat" => { "dummy" => true }
        }
      }

      # pretend nfslock does not exist
      @READ2 = deep_copy(@READ) # copy on write works
      Ops.set(@READ2, ["init", "scripts", "exists"], false)

      @WRITE = {}

      @WRITE_KO = { "etc" => { "exports" => false } }

      @EXECUTE = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" },
          "mkdir"       => true
        }
      }

      NfsServer.write_only = false

      DUMP("Read")
      TEST(lambda { NfsServer.Read }, [[@READ, @READ2], @WRITE, @EXECUTE], nil)
      DUMP("Write OK")
      TEST(lambda { NfsServer.Write }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP("Write KO")
      TEST(lambda { NfsServer.Write }, [@READ, @WRITE_KO, @EXECUTE], nil)

      nil
    end
  end
end

Yast::ReadwriteUnfsdClient.new.main
