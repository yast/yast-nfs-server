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
  class Readwrite2Client < Client
    def main
      # testedfiles: NfsServer.ycp Service.ycp Report.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @I_READ = { "target" => { "size" => 0 } }
      @I_WRITE = {}
      @I_EXEC = { "target" => { "bash_output" => {} } }
      TESTSUITE_INIT([@I_READ, @I_WRITE, @I_EXEC], nil)

      Yast.import "NfsServer"
      Yast.import "Report"

      NfsServer.write_only = false
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
              "rpcbind"   => @service_on,
              "nfsserver" => @service_on
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
      #   not used
      @READ2 = deep_copy(@READ)
      Ops.set(@READ2, ["init", "scripts", "exists"], false)

      # services rpcbind & nfsserver are stopped
      @READ3 = deep_copy(@READ)
      Ops.set(@READ3, ["init", "scripts", "runlevel", "rpcbind"], @service_off)
      Ops.set(
        @READ3,
        ["init", "scripts", "runlevel", "nfsserver"],
        @service_off
      )

      @WRITE = {}

      # not used
      @WRITE_KO = { "etc" => { "exports" => false } }

      @EXECUTE = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" },
          "mkdir"       => true
        }
      }

      # nfsserver and rpcbind are running
      DUMP("\nRead  - services are running\n")
      TEST(lambda { NfsServer.Read }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP("\nWrite - services will be stopped\n")
      # Stop services!
      NfsServer.start = false
      # And Write
      TEST(lambda { NfsServer.Write }, [@READ, @WRITE, @EXECUTE], nil)

      # nfsserver and rpcbind are running
      DUMP("\nRead  - services are running\n")
      TEST(lambda { NfsServer.Read }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP("\nWrite - services are running\n")
      # Start services (nfsserver)
      NfsServer.start = true
      # And Write
      TEST(lambda { NfsServer.Write }, [@READ, @WRITE, @EXECUTE], nil)

      # nfsserver and rpcbind are stopped
      DUMP("\nRead  - services are stopped\n")
      TEST(lambda { NfsServer.Read }, [@READ3, @WRITE, @EXECUTE], nil)
      DUMP("\nWrite - services will be stopped\n")
      # Leave services stopped
      NfsServer.start = false
      # And Write
      TEST(lambda { NfsServer.Write }, [@READ3, @WRITE, @EXECUTE], nil)

      # nfsserver and rpcbind are stopped
      DUMP("\nRead  - services are stopped\n")
      TEST(lambda { NfsServer.Read }, [@READ3, @WRITE, @EXECUTE], nil)
      DUMP("\nWrite - services will be started\n")
      # Start services
      NfsServer.start = true
      # And Write
      TEST(lambda { NfsServer.Write }, [@READ3, @WRITE, @EXECUTE], nil)

      nil
    end
  end
end

Yast::Readwrite2Client.new.main
