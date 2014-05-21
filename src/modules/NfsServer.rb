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

module Yast
  class NfsServerClass < Module
    def main
      textdomain "nfs_server"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "Summary"
      Yast.import "SuSEFirewall"
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

      # Domain name to be used for nfsv4 (idmapd.conf)
      @domain = ""

      # Should the server be started?
      # New since 9.0: Exports are independent of this setting.
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

      # Do we have nfslock? (nfs-utils: yes, nfs-server: no)
      # FIXME: check nfs-kernel-server
      @have_nfslock = true

      # Since SLE 11, there's no portmapper, but rpcbind
      @portmapper = "rpcbind"
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Get all NFS server configuration from a map.
    # When called by nfs_server_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings	$["start_nfsserver": "nfs_exports":]
    # @return	success
    # @see #exports
    def Import(settings)
      settings = deep_copy(settings)
      # if (size (settings) == 0)
      # {
      #     // Reset - just continue with Set (#24544).
      # }

      # To avoid enabling nfslock if it does not exist during autoinstall
      @have_nfslock = Convert.to_boolean(
        SCR.Read(path(".init.scripts.exists"), "nfslock")
      )
      Set(settings)
      true
    end

    # Set the variables just as is and without complaining
    # @param [Hash] settings $[ start_nfsserver:, nfs_exports:, ]
    def Set(settings)
      settings = deep_copy(settings)
      @start = Ops.get_boolean(settings, "start_nfsserver", false)
      @exports = Ops.get_list(settings, "nfs_exports", [])
      # #260723, #287338: fix wrongly initialized variables
      # but do not extend the schema yet
      @enable_nfsv4 = false
      @domain = ""
      @nfs_security = false

      nil
    end


    # Dump the NFS settings to a map, for autoinstallation use.
    # @return	$["start_nfsserver": "nfs_exports":]
    # @see #exports
    def Export
      { "start_nfsserver" => @start, "nfs_exports" => @exports }
    end

    # Reads NFS settings from the SCR (.etc.exports),
    # from SCR (.sysnconfig.nfs) and SCR (.etc.idmapd_conf),if necessary.
    # @return true on success
    def Read
      @start = Service.Enabled("nfsserver")
      @exports = Convert.convert(
        SCR.Read(path(".etc.exports")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      @have_nfslock = Convert.to_boolean(
        SCR.Read(path(".init.scripts.exists"), "nfslock")
      )
      @enable_nfsv4 = SCR.Read(path(".sysconfig.nfs.NFS4_SUPPORT")) == "yes"
      @nfs_security = SCR.Read(path(".sysconfig.nfs.NFS_SECURITY_GSS")) == "yes"

      if @enable_nfsv4
        @domain = Convert.to_string(
          SCR.Read(path(".etc.idmapd_conf.value.General.Domain"))
        )
      end

      progress_orig = Progress.set(false)
      SuSEFirewall.Read
      Progress.set(progress_orig)

      @exports != nil
    end


    # Saves /etc/exports and creates missing directories.
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
    # Creates any missing directories.
    # @return true on success
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
        if !SCR.Write(path(".etc.idmapd_conf.value.General.Domain"), @domain) ||
            !SCR.Write(path(".etc.idmapd_conf"), nil)
          Report.Error(_("Unable to write to idmapd.conf."))
        end
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
        Service.Stop("nfsserver") if !@write_only

        if !Service.Disable("nfsserver")
          Report.Error(Service.Error)
          ok = false
        end
        if @have_nfslock
          Service.Stop("nfslock") if !@write_only
          if !Service.Disable("nfslock")
            Report.Error(Service.Error)
            ok = false
          end
        end
      else
        if !Service.Enable(@portmapper)
          Report.Error(Service.Error)
          ok = false
        end
        if @have_nfslock
          if !Service.Enable("nfslock")
            Report.Error(Service.Error)
            ok = false
          end
        end
        if !Service.Enable("nfsserver")
          Report.Error(Service.Error)
          ok = false
        end

        if @enable_nfsv4
          if !Service.active?("idmapd")
            unless Service.Start("idmapd")
              Report.Error(
                _("Unable to start idmapd. Check your domain setting.")
              )
              ok = false
            end
          else
            unless Service.Restart("idmapd")
              Report.Error(_("Unable to restart idmapd."))
              ok = false
            end
          end
        else
          unless Service.active?("idmapd")
            unless Service.Stop("idmapd")
              Report.Error(_("Unable to stop idmapd."))
              ok = false
            end
          end
        end

        if @nfs_security
          if !Service.active?("svcgssd")
            unless Service.Start("svcgssd")
              # FIXME svcgssd is gone! (only nfsserver is left)
              Report.Error(
                _(
                  "Unable to start svcgssd. Ensure your kerberos and gssapi (nfs-utils) setup is correct."
                )
              )
              ok = false
            end
          else
            unless Service.Restart("svcgssd")
              Report.Error(
                _("Unable to restart 'svcgssd' service.")
              )
              ok = false
            end
          end
        else
          if Service.active?("svcgssd")
            unless Service.Stop("svcgssd")
              Report.Error(_("'svcgssd' is running. Unable to stop it."))
              ok = false
            end
          end
        end

        if !@write_only
          unless Service.active?(@portmapper)
            Service.Start(@portmapper)
          end

          Service.Stop("nfsserver")
          Service.Restart("nfslock") if @have_nfslock
          Service.Start("nfsserver")

          unless Service.active?("nfsserver")
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
      SuSEFirewall.WriteOnly
      SuSEFirewall.ActivateConfiguration if !@write_only
      Progress.set(progress_orig)

      Progress.NextStage

      ok
    end

    # @return A summary for autoyast
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
        summary = Summary.AddLine(
          summary,
          Builtins.sformat(_("The NFSv4 domain for idmapping is %1."), @domain)
        )
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
    # @return [Hash] of packages to be installed and to be removed
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
    publish :variable => :domain, :type => "string"
    publish :variable => :start, :type => "boolean"
    publish :variable => :exports, :type => "list <map <string, any>>"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :WriteExports, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :AutoPackages, :type => "map ()"
  end

  NfsServer = NfsServerClass.new
  NfsServer.main
end
