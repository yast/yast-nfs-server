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
  class Routines2Client < Client
    def main
      # testedfiles: routines.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "nfs_server/routines.rb"

      @test_options = "secure,insecure,rw,ro,sync,async,no_wdelay,wdelay,nohide,hide,no_subtree_check,subtree_check,insecure_locks,secure_locks,no_auth_nlm,auth_nlm,root_squash,no_root_squash,all_squash,no_all_squash"

      @exports = [
        { "allowed" => ["proj*.local.domain(rw)"], "mountpoint" => "/projects" },
        {
          "allowed"    => ["*.local.domain(ro)", "@trusted(rw)"],
          "mountpoint" => "/usr"
        },
        { "allowed" => ["(ro,insecure,all_squash)"], "mountpoint" => "/pub" }
      ]

      TEST(lambda { CheckNoSpaces("no_spaces") }, [], nil)
      TEST(lambda { CheckNoSpaces(" space_before") }, [], nil)
      TEST(lambda { CheckNoSpaces("space inside") }, [], nil)
      TEST(lambda { CheckNoSpaces(" space_before and inside") }, [], nil)
      TEST(lambda { CheckNoSpaces("space_after ") }, [], nil)
      TEST(lambda { CheckNoSpaces(" before inside after ") }, [], nil)
      TEST(lambda { CheckNoSpaces("tab\tulator") }, [], nil)

      TEST(lambda { CheckExportOptions("rw,all_squash") }, [], nil)
      TEST(lambda { CheckExportOptions("invalid:options <> ?") }, [], nil)
      # colon is valid
      TEST(lambda { CheckExportOptions("sec=none:kerb5") }, [], nil)

      TEST(lambda { CheckExportOptions_strict("ro,insecure,all_squash") }, [], nil)
      TEST(lambda { CheckExportOptions_strict(@test_options) }, [], nil)
      TEST(lambda do
        CheckExportOptions_strict(Ops.add(@test_options, ",some_invalid"))
      end, [], nil)
      TEST(lambda { CheckExportOptions_strict("ro,invalid_option") }, [], nil)

      nil
    end
  end
end

Yast::Routines2Client.new.main
