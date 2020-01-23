# encoding: utf-8

# File:
#   nfs_server.ycp
#
# Module:
#   Configuration of nfs_server
#
# Summary:
#   Module for the configuration of the nfs server
#
# Authors:
#   Jan Holesovsky <kendy@suse.cz>
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Module for the configuration of the nfs server

#**
# <h3>Configuration of the nfs_server</h3>
module Yast
  class NfsServerClient < Client
    def main
      Yast.import "UI"

      textdomain "nfs_server"

      Yast.import "CommandLine"
      # FIXME also apply to autoyast part,
      # must be able to query packages in selections
      Yast.import "NfsServer"
      Yast.import "Package"
      Yast.import "Report"
      Yast.import "RichText"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include self, "nfs_server/ui.rb"


      @cmdline_description = {
        "id"         => "nfs-server",
        # Command line help text for the nfs-server module
        "help"       => _(
          "Configuration of NFS server"
        ),
        "guihandler" => fun_ref(method(:NfsServerSequence), "any ()"),
        "initialize" => fun_ref(NfsServer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(NfsServer.method(:Write), "boolean ()"),
        "actions"    => {
          "summary" => {
            "handler"  => fun_ref(
              method(:NfsServerSummaryHandler),
              "boolean (map)"
            ),
            # command line action help
            "help"     => _(
              "NFS server configuration summary"
            ),
            "readonly" => true
          },
          "start"   => {
            "handler" => fun_ref(
              method(:NfsServerStartHandler),
              "boolean (map)"
            ),
            "help"    => _("Start NFS server")
          },
          "stop"    => {
            "handler" => fun_ref(method(:NfsServerStopHandler), "boolean (map)"),
            "help"    => _("Stop NFS server")
          },
          "add"     => {
            "handler" => fun_ref(method(:NfsServerAddHandler), "boolean (map)"),
            "help"    => _("Add a directory to export")
          },
          "delete"  => {
            "handler" => fun_ref(
              method(:NfsServerDeleteHandler),
              "boolean (map)"
            ),
            "help"    => _("Delete a directory from export")
          },
          "set"     => {
            "handler" => fun_ref(
              method(:NfsServerSetOptionHandler),
              "boolean (map)"
            ),
            "help"    => _(
              "Set the parameters for domain, security and enablev4."
            )
          }
        },
        "options"    => {
          "mountpoint" => {
            "type" => "string",
            "help" => _("Directory to export")
          },
          "hosts"      => {
            "type" => "string",
            "help" => _("Host wild card for setting the access to directory")
          },
          "options"    => {
            "type" => "string",
            # command line option help (do not transl. 'man exports')
            "help" => _(
              "Export options (see 'man exports')"
            )
          },
          "domain"     => {
            "type" => "string",
            "help" => _(
              "Domain specification for NFSv4 ID mapping, such as 'localdomain' or 'abc.com' etc."
            )
          },
          "enablev4"   => {
            "type"     => "enum",
            "typespec" => ["yes", "no"],
            "help"     => _(
              "'yes'/'no option for enabling/disabling support for NFSv4."
            )
          },
          "security"   => {
            "type"     => "enum",
            "typespec" => ["yes", "no"],
            "help"     => _("'yes'/'no' option for enabling/disabling secure NFS.")
          }
        },
        "mappings"   => {
          "summary" => [],
          "start"   => [],
          "stop"    => [],
          "add"     => ["mountpoint", "hosts", "options"],
          "delete"  => ["mountpoint"],
          "set"     => ["enablev4", "domain", "security"]
        }
      }

      # main ui function
      @ret = nil

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("NFS module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end

    # GUI handler
    # @return `ws_finish `back or `abort
    def NfsServerSequence
      _Aliases = { "begin" => lambda { BeginDialog() }, "exports" => lambda do
        ExportsDialog()
      end }

      _Sequence = {
        "ws_start" => "begin",
        "begin"    => {
          :next   => "exports",
          :finish => :ws_finish,
          :abort  => :abort
        },
        "exports"  => { :next => :ws_finish, :abort => :abort }
      }

      Package.InstallAll(NfsServer.required_packages) or return nil

      if !NfsServer.Read
        Builtins.y2error("read error, bye")
        return nil
      end

      CheckSyntaxErrors(NfsServer.exports)

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.NFSServer")

      result = Sequencer.Run(_Aliases, _Sequence)

      NfsServer.Write if result == :ws_finish

      UI.CloseDialog
      deep_copy(result)
    end

    # CLI action handler.
    # Print summary in command line
    # @param [Hash] options command options
    # @return false so that Write is not called in non-interactive mode
    def NfsServerSummaryHandler(options)
      options = deep_copy(options)
      if NfsServer.start
        # summary text
        CommandLine.Print(_("NFS server is enabled"))
      else
        # summary text
        CommandLine.Print(_("NFS server is disabled"))
      end

      CommandLine.Print(RichText.Rich2Plain(NfsServer.Summary))
      true
    end

    # check if neccessary packages are installed
    # Report error if not
    # @return success?
    def check_packages
      packages = Builtins.add(NfsServer.required_packages, "nfs-server")
      if !Package.InstalledAny(packages)
        # error message
        Report.Error(
          Builtins.sformat(
            _("Required packages (%1) are not installed."),
            Builtins.mergestring(NfsServer.required_packages, ",")
          )
        )
        return false
      end
      true
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsServerStartHandler(options)
      if NfsServer.start
        CommandLine.Print(_("NFS server already running."))
        return false
      end
      return false if !check_packages
      NfsServer.start = true
      true
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsServerStopHandler(options)
      if !NfsServer.start
        CommandLine.Print(_("NFS server is already stopped."))
        return false
      end
      return false if !NfsServer.start
      NfsServer.start = false
      true
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsServerAddHandler(options)
      options = deep_copy(options)
      return false if !check_packages

      mountpoint = Ops.get_string(options, "mountpoint", "")
      if mountpoint == ""
        # error
        CommandLine.Print(_("No mount point specified."))
        return false
      end
      exports = deep_copy(NfsServer.exports)
      if FindAllowed(exports, mountpoint) != nil
        Report.Message(_("The exports table already\ncontains this directory."))
        return false
      end
      host = Ops.get_string(options, "hosts", "")
      host = "*" if host == ""
      opts = Ops.get_string(options, "options", "")
      opts = @default_options if opts == ""
      default_allowed = [Builtins.sformat("%1(%2)", host, opts)]
      exports = Builtins.add(
        exports,
        { "mountpoint" => mountpoint, "allowed" => default_allowed }
      )
      return false if !CheckNoSpaces(host) || !CheckExportOptions(opts)
      NfsServer.exports = deep_copy(exports)
      true
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsServerDeleteHandler(options)
      options = deep_copy(options)
      mountpoint = Ops.get_string(options, "mountpoint", "")
      if mountpoint == ""
        # error
        CommandLine.Print(_("No mount point specified."))
        return false
      end
      deleted = false
      NfsServer.exports = Builtins.filter(NfsServer.exports) do |entry|
        if Ops.get_string(entry, "mountpoint", "") != mountpoint
          next true
        else
          deleted = true
          next false
        end
      end

      CommandLine.Print(_("Mount point not found.")) if !deleted

      deleted
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsServerSetOptionHandler(options)
      options = deep_copy(options)
      nfs_sec = Ops.get_string(options, "security", "")
      v4domain = Ops.get_string(options, "domain", "")
      enablev4 = Ops.get_string(options, "enablev4", "")

      NfsServer.nfs_security = true if nfs_sec == "yes"
      NfsServer.nfs_security = false if nfs_sec == "no"

      NfsServer.enable_nfsv4 = true if enablev4 == "yes"
      NfsServer.enable_nfsv4 = false if enablev4 == "no"

      if v4domain != ""
        if !NfsServer.enable_nfsv4
          CommandLine.Print(
            _(
              "Domain cannot be set without enabling NFSv4. Use the 'set enablev4=yes' command."
            )
          )
          return false
        end
        NfsServer.domain = v4domain
      end

      if nfs_sec == "" && enablev4 == "" && v4domain == ""
        CommandLine.Print(
          _(
            "Command 'set' must be used in the form 'set option=value'. Use 'set help' to get information about available options."
          )
        )
        return false
      end

      true
    end
  end
end

Yast::NfsServerClient.new.main
