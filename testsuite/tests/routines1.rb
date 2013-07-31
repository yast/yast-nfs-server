# encoding: utf-8

# Module:
#   NFS server configuration
#
# Summary:
#   Routines testsuite
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class Routines1Client < Client
    def main
      # testedfiles: routines.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "nfs_server/routines.rb"

      @exports = [
        { "allowed" => ["proj*.local.domain(rw)"], "mountpoint" => "/projects" },
        {
          "allowed"    => ["*.local.domain(ro)", "@trusted(rw)"],
          "mountpoint" => "/usr"
        },
        { "allowed" => ["(ro,insecure,all_squash)"], "mountpoint" => "/pub" }
      ]

      TEST(lambda { AllowedToHostsOpts("host.com(options)") }, [], nil)
      TEST(lambda { AllowedToHostsOpts("noopts.host.com") }, [], nil)
      TEST(lambda { AllowedToHostsOpts("host.com(noclose") }, [], nil)
      TEST(lambda { AllowedToHostsOpts("host.com((double))") }, [], nil)
      TEST(lambda { AllowedToHostsOpts("") }, [], nil)

      TEST(lambda { AllowedTableItems(["*.local.domain(ro)", "@trusted(rw)"]) }, [], nil)
      TEST(lambda { AllowedTableItems([]) }, [], nil)

      TEST(lambda { FindAllowed(@exports, "/pub") }, [], nil)
      TEST(lambda { FindAllowed(@exports, "/nosuchpath") }, [], nil)
      TEST(lambda { FindAllowed([], "/pub") }, [], nil)

      TEST(lambda { ExportsItems(@exports) }, [], nil)
      TEST(lambda { ExportsItems([]) }, [], nil)

      TEST(lambda { ExportsSelBox(@exports) }, [], nil)
      TEST(lambda { ExportsSelBox([]) }, [], nil)

      TEST(lambda { ReplaceInExports(@exports, "/usr", ["*.localdomain(ro)"]) }, [], nil)
      TEST(lambda do
        ReplaceInExports(@exports, "/nosuchpath", ["*.localdomain(ro)"])
      end, [], nil)
      TEST(lambda { ReplaceInExports([], "/whatever", ["*.localdomain(ro)"]) }, [], nil)

      nil
    end
  end
end

Yast::Routines1Client.new.main
