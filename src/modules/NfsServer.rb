# encoding: utf-8

# File:
#   modules/NfsServer.ycp
#
# Module:
#   Configuration of nfs_server
#
# Summary:
#   NFS server configuration data, I/O functions.
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
require "yast"
require "y2firewall/firewalld"

module Yast
  class NfsServerClass < Module
    SERVICE = "nfs-server".freeze
    GSSERVICE = "rpc-svcgssd".freeze
    
    def main
      textdomain "nfs_server"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "Summary"
      Yast.import "Wizard"

      # default value of settings modified
      @modified = false

      # Required packages for this module to operate
      #
      @required_packages = ["nfs-kernel-server"]

      # Write only, used during autoinstallation.
      # Don't run services and SuSEconfig, it's all done at one place.
      @write_only = false

      # Enable nfsv4
      @enable_nfsv4 = true

      # GSS Security ?
      @nfs_security = false

      # Should the server be started?
      # Exports are independent of this setting.
      @start = false

      # @example
      # [
      #   $[
      #     "mountpoint": "/projects",
      #     "allowed": [ "*.local.domain(ro)", "@trusted(rw)"]
      #   ],
      #   $[ ... ],
      #   ...
      # ]
      #
      @exports = []

      # Since SLE 11, there's no portmapper, but rpcbind
      @portmapper = "rpcbind"
    end

    # Sets an internal variable to indicate if settings were modified
    def SetModified
      @modified = true

      nil
    end

    # Whether the settings were modified
    #
    # @return [Boolean]
    def GetModified
      @modified
    end

    # Get all NFS server configuration from a map.
    #
    # When called by nfs_server_auto (preparing autoinstallation data) the map may be empty.
    #
    # @param [Hash] settings
    # @option settings [Boolean] start_nfsserver
    # @option settings [Array] nfs_exports
    #
    # @see #exports
    #
    # @return	[true]
    def Import(settings)
      settings = deep_copy(settings)
      Set(settings)
      true
    end

    # Set the variables just as is and without complaining
    #
    # @param [Hash] settings
    # @option settings [Boolean] start_nfsserver
    # @option settings [Array] nfs_exports
    def Set(settings)
      settings = deep_copy(settings)
      @start = Ops.get_boolean(settings, "start_nfsserver", false)
      @exports = Ops.get_list(settings, "nfs_exports", [])
      # #260723, #287338: fix wrongly initialized variables
      # but do not extend the schema yet
      @enable_nfsv4 = false
      @nfs_security = false

      nil
    end

    # Dump the NFS settings to a map, for autoinstallation use.
    #
    # @see #exports
    #
    # @return [Hash] a map with NFS settings, necessary for autoinstallation
    #   * "start_nfsserver" [Boolean]
    #   * "nfs_exports" [Array]
    def Export
      { "start_nfsserver" => @start, "nfs_exports" => @exports }
    end

    # Reads NFS settings
    #
    # From the SCR (.etc.exports), (.sysnconfig.nfs), and (.etc.idmapd_conf) if necessary.
    #
    # @return [Boolean] true on success; false otherwise
    def Read
      @start = Service.Enabled(SERVICE)
      @exports = Convert.convert(
        SCR.Read(path(".etc.exports")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      @enable_nfsv4 = SCR.Read(path(".sysconfig.nfs.NFS4_SUPPORT")) == "yes"
      @nfs_security = SCR.Read(path(".sysconfig.nfs.NFS_SECURITY_GSS")) == "yes"

      progress_orig = Progress.set(false)
      firewalld.read
      Progress.set(progress_orig)

      @exports != nil
    end


    # Saves /etc/exports and creates missing directories.
    #
    # @return true on success
    def WriteExports
      # create missing directories.
      Builtins.foreach(@exports) do |entry|
        directory = Ops.get_string(entry, "mountpoint")
        if SCR.Read(path(".target.dir"), directory) == nil
          if !Convert.to_boolean(SCR.Execute(path(".target.mkdir"), directory))
            # not fatal - write other dirs.
            Report.Warning(
              Builtins.sformat(
                _("Unable to create a missing directory:\n%1"),
                directory
              )
            )
          end
        end
      end

      # (the backup is now done by the agent)
      if !SCR.Write(path(".etc.exports"), @exports)
        # error popup message
        Report.Error(
          _(
            "Unable to write to /etc/exports.\n" +
              "No changes will be made to the\n" +
              "exported directories.\n"
          )
        )
        return false
      end

      true
    end

    # Saves NFS server configuration. (exports(5))
    #
    # @note It creates any missing directories.
    #
    # @return [Boolean] true on success; false otherwise
    def Write
      # if there is still work to do, don't return false immediately
      # but remember the error
      ok = true

      # dialog label
      Progress.New(
        _("Writing NFS Server Configuration"),
        " ",
        2,
        [
          # progress stage label
          _("Save /etc/exports"),
          # progress stage label
          _("Restart services")
        ],
        [
          # progress step label
          _("Saving /etc/exports..."),
          # progress step label
          _("Restarting services..."),
          # final progress step label
          _("Finished")
        ],
        ""
      )

      # help text
      if !@write_only
        # help text
        Wizard.RestoreHelp(_("Writing NFS server settings. Please wait..."))
      end

      Progress.NextStage

      # Independent of @ref start because of Heartbeat (#27001).
      if !WriteExports()
        Progress.Finish
        return false
      end
      if @enable_nfsv4
        SCR.Write(path(".sysconfig.nfs.NFS4_SUPPORT"), "yes")
      else
        SCR.Write(path(".sysconfig.nfs.NFS4_SUPPORT"), "no")
      end

      if @nfs_security
        SCR.Write(path(".sysconfig.nfs.NFS_SECURITY_GSS"), "yes")
      else
        SCR.Write(path(".sysconfig.nfs.NFS_SECURITY_GSS"), "no")
      end
      SCR.Write(path(".sysconfig.nfs"), nil)

      Progress.NextStage

      if !@start
        Service.Stop(SERVICE) if !@write_only

        if !Service.Disable(SERVICE)
          Report.Error(Service.Error)
          ok = false
        end
      else
        if !Service.Enable(@portmapper)
          Report.Error(Service.Error)
          ok = false
        end
        if !Service.Enable(SERVICE)
          Report.Error(Service.Error)
          ok = false
        end

        if @nfs_security
          if !Service.active?(GSSERVICE)
            unless Service.Start(GSSERVICE)
              # FIXME #{GSSERVICE} is gone! (only nfsserver is left)
              Report.Error(
                _(
                  "Unable to start svcgssd. Ensure your kerberos and gssapi (nfs-utils) setup is correct."
                )
              )
              ok = false
            end
          else
            unless Service.Restart(GSSERVICE)
              Report.Error(
                _("Unable to restart 'svcgssd' service.")
              )
              ok = false
            end
          end
        else
          if Service.active?(GSSERVICE)
            unless Service.Stop(GSSERVICE)
              Report.Error(_("'svcgssd' is running. Unable to stop it."))
              ok = false
            end
          end
        end

        if !@write_only
          unless Service.active?(@portmapper)
            Service.Start(@portmapper)
          end

          Service.Restart(SERVICE)

          unless Service.active?(SERVICE)
            # error popup message
            Report.Error(
              _(
                "Unable to restart the NFS server.\nYour changes will be active after reboot.\n"
              )
            )
            ok = false
          end
        end
      end

      progress_orig = Progress.set(false)
      @write_only ? firewalld.write_only : firewalld.write
      Progress.set(progress_orig)

      Progress.NextStage

      ok
    end

    # @return [String] A summary for AutoYaST
    def Summary
      summary = ""
      # summary header; directories exported by NFS
      summary = Summary.AddHeader(summary, _("NFS Exports"))
      if Ops.greater_than(Builtins.size(@exports), 0)
        Builtins.foreach(@exports) do |e|
          summary = Summary.OpenList(summary)
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(e, "mountpoint", "")
          )
          summary = Summary.CloseList(summary)
        end
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      # add information reg NFSv4 support, domain and security
      if @enable_nfsv4
        summary = Summary.AddLine(summary, "NFSv4 support is enabled.")
      else
        summary = Summary.AddLine(summary, "NFSv4 support is disabled.")
      end

      if @nfs_security
        summary = Summary.AddLine(summary, "NFS Security using GSS is enabled.")
      else
        summary = Summary.AddLine(
          summary,
          "NFS Security using GSS is disabled."
        )
      end

      summary
    end

    # Return required packages for auto-installation
    #
    # @return [Hash] list of packages to be installed or removed
    #   * "install" [Array] packages to be installed
    #   * "remove" [Array] an empty array since there is nothing to be removed
    def AutoPackages
      { "install" => @required_packages, "remove" => [] }
    end

    publish :variable => :modified, :type => "boolean"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :Set, :type => "void (map)"
    publish :variable => :required_packages, :type => "list <string>"
    publish :variable => :write_only, :type => "boolean"
    publish :variable => :enable_nfsv4, :type => "boolean"
    publish :variable => :nfs_security, :type => "boolean"
    publish :variable => :start, :type => "boolean"
    publish :variable => :exports, :type => "list <map <string, any>>"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :WriteExports, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :AutoPackages, :type => "map ()"

  private

    def firewalld
      Y2Firewall::Firewalld.instance
    end
  end

  NfsServer = NfsServerClass.new
  NfsServer.main
end
