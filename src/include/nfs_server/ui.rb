# encoding: utf-8

# File:
#   ui.ycp
#
# Module:
#   NFS server
#
# Summary:
#   Network NFS server dialogs
#
# Authors:
#   Jan Holesovky <kendy@suse.cz>
#   Dan Vesely (dan@suse.cz)
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Network NFS server dialogs
#
module Yast
  module NfsServerUiInclude
    def initialize_nfs_server_ui(include_target)
      Yast.import "UI"

      textdomain "nfs_server"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "NfsServer"
      Yast.import "Popup"
      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.include include_target, "nfs_server/routines.rb"
    end

    # Ask user for a directory to export. Allow browsing.
    # @param [String] mountpoint	default value
    # @param [Array<Hash>] exports		exports list to check for duplicates
    # @return			a path to export or nil if cancelled
    def GetDirectory(mountpoint, exports)
      exports = deep_copy(exports)
      Wizard.SetScreenShotName("nfs-server-2a-dir")

      mountpoint = "" if mountpoint == nil

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.2),
            HBox(
              TextEntry(
                Id(:mpent),
                # text entry label
                _("&Directory to Export"),
                mountpoint
              ),
              HSpacing(1),
              VBox(
                # button label
                Bottom(PushButton(Id(:browse), Opt(:key_F6), _("&Browse...")))
              )
            ),
            VSpacing(0.2),
            ButtonBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.2)
          ),
          HSpacing(1)
        )
      )
      UI.SetFocus(Id(:mpent))

      ret = nil
      begin
        ret = UI.UserInput
        mountpoint = Convert.to_string(UI.QueryWidget(Id(:mpent), :Value))

        if ret == :ok
          if mountpoint == nil || mountpoint == ""
            Popup.Message(
              _("Enter a non-empty export path. For example, /exports.")
            )
            ret = nil
          else
            allowed = FindAllowed(exports, mountpoint)
            if allowed != nil
              # error popup message
              Popup.Message(
                _("The exports table already contains this directory.")
              )
              ret = nil
            elsif Ops.less_than(SCR.Read(path(".target.size"), mountpoint), 0) &&
                !Mode.config
              # the dir does not exist
              ret = Popup.YesNo(_("The directory does not exist. Create it?")) ? :ok : nil
            end
          end
        elsif ret == :browse
          dir = Convert.to_string(UI.QueryWidget(Id(:mpent), :Value))
          dir = "/" if Builtins.size(dir) == 0

          # title in the file selection dialog
          dir = UI.AskForExistingDirectory(
            dir,
            _("Select the Directory to Export")
          )

          if Ops.greater_than(Builtins.size(dir), 0)
            len = Builtins.size(dir)
            # remove the trailing "/"
            if dir != "/" &&
                Builtins.substring(dir, Ops.subtract(len, 1), 1) == "/"
              dir = Builtins.substring(dir, 0, Ops.subtract(len, 1))
            end
            UI.ChangeWidget(Id(:mpent), :Value, dir)
          end
        end
      end while ret != :ok && ret != :cancel

      UI.CloseDialog
      Wizard.RestoreScreenShotName

      return mountpoint if ret == :ok
      nil
    end


    # Ask user for an entry for the allowed hosts list.
    # @param [Array<Hash>] exports   the current UI version of the exports list
    # @param [String] expath	the exported filesystem for which this is done
    # @param [String] hosts	hosts default value
    # @param [String] opts	options default value
    # @param [Array<String>] allowed	current list, to check for duplicates
    # @return		[newhosts, newopts] or nil if cancelled. Options without parentheses.
    def GetAllowedHosts(exports, expath, hosts, opts, allowed, fromedit)
      exports = deep_copy(exports)
      allowed = deep_copy(allowed)
      Wizard.SetScreenShotName("nfs-server-2b-hosts")
      error = nil
      event = nil
      hostchanged = false
      optchanged = false

      hosts = "" if hosts == nil
      opts = "" if opts == nil
      allowed = [] if allowed == nil
      allowed_names = Builtins.maplist(allowed) do |str|
        brpos = Builtins.findfirstof(str, "(")
        str = Builtins.substring(str, 0, brpos) if str != nil
        str
      end

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.2),
            # make at least the default options fit
            HSpacing(30),
            # text entry label
            TextEntry(Id(:hostsent), Opt(:notify), _("&Host Wild Card"), hosts),
            # text entry label
            TextEntry(Id(:optsent), Opt(:notify), _("O&ptions"), opts),
            VSpacing(0.2),
            # ok pushbutton: confirm the dialog
            ButtonBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.2)
          ),
          HSpacing(1)
        )
      )

      UI.SetFocus(Id(:hostsent))
      ret = nil
      begin
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")

        if ret == :hostsent
          hosts = Convert.to_string(UI.QueryWidget(Id(:hostsent), :Value))
          UI.ChangeWidget(Id(:hostsent), :Value, hosts)
          hostchanged = true if !hostchanged
          next
        end

        hosts = Convert.to_string(UI.QueryWidget(Id(:hostsent), :Value))
        if hosts == ""
          hosts = "*"
          UI.ChangeWidget(Id(:hostsent), :Value, hosts)
        end

        if ret == :optsent
          # Update the opts value when changed, otherwise the value validated
          # later could be the cached one.
          opts = Convert.to_string(UI.QueryWidget(Id(:optsent), :Value))
          # check to see if user has changed options entry in the dialogue
          # thrown due to a "Add Hosts" (as opposed to editing existing ones).
          # If yes, suggest the user with a suitable default option set.
          if hostchanged && !fromedit
            if !optchanged
              hosts = Convert.to_string(UI.QueryWidget(Id(:hostsent), :Value))
              opts = GetDefaultOpts(exports, hosts)
              UI.ChangeWidget(Id(:optsent), :Value, opts)
              optchanged = true
            end
          end
        end

        if ret == :ok && (!CheckNoSpaces(hosts) || !CheckExportOptions(opts))
          ret = nil
        end
        if ret == :ok && !NfsServer.enable_nfsv4
          if Builtins.issubstring(opts, "fsid=0")
            Popup.Message(
              _(
                "'fsid=0' is not a valid option unless \nNFSv4 is enabled (previous page).\n"
              )
            )
            ret = nil
          end
        end

        if ret == :ok && NfsServer.enable_nfsv4
          error = CheckUniqueRootForClient(exports, expath, hosts, opts)
          if error != nil
            Popup.Message(error)
            ret = nil
          end
        end

        if ret == :ok && Builtins.contains(allowed_names, hosts)
          # error popup message
          Popup.Message(_("Options for this wild card\nare already set."))
          ret = nil
        end
      end while ret != :ok && ret != :cancel

      opts = Convert.to_string(UI.QueryWidget(Id(:optsent), :Value))
      UI.CloseDialog

      if opts == ""
        opts = GetDefaultOpts(exports, hosts)
      end

      opts = Builtins.deletechars(opts, " ()")

      Wizard.RestoreScreenShotName

      return [hosts, opts] if ret == :ok
      nil
    end


    # Opening NFS server dialog
    # @return `back, `abort, `next `or finish
    def BeginDialog
      Wizard.SetScreenShotName("nfs-server-1-start")

      start_nfs_server = NfsServer.start
      domain = Convert.to_string(
        SCR.Read(path(".etc.idmapd_conf.value.General.Domain"))
      )
      if domain == nil
        Popup.Message(
          _(
            "Unable to read the /etc/idmapd.conf file. Setting the default setting for the domain to 'localdomain'."
          )
        )
        domain = "localdomain"
      end

      enable_nfsv4 = NfsServer.enable_nfsv4
      nfs_security = NfsServer.nfs_security

      changed = false

      fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        "services"        => ["nfs-kernel-server"],
        "display_details" => true
      )

      help_text =
        # Help, part 1 of 2
        _(
          "<P>Here, choose whether to start an NFS server on your computer\nand export some of your directories to others.</P>"
        )

      help_text = Ops.add(
        help_text,
        # Help, part 2 of 2
        _(
          "<P>If you choose <B>Start NFS Server</B>, clicking <B>Next</B> opens\na configuration dialog in which to specify the directories to export.</P>"
        )
      )

      help_text = Ops.add(help_text, Ops.get_string(fw_cwm_widget, "help", ""))

      help_text = Ops.add(
        help_text,
        _(
          "<P>If the server needs to handle NFSv4 clients, check <B>Enable NFSv4</B>\n" +
            "and fill in the NFSv4 domain name you want the ID mapping daemon to use. Leave\n" +
            "it as localdomain or refer to the man page for idmapd and idmapd.conf if you are not sure.</P>\n"
        )
      )

      help_text = Ops.add(
        help_text,
        # FIXME: use %1 as nfs-utils.src.rpm produces nfs-kernel-server.rpm
        _(
          "<P>If the server and client must authenticate using GSS library, check the\n<B>Enable GSS Security</B> box. To use GSS API, you currently need to have Kerberos and gssapi (nfs-utils > 1.0.7) on your system.</P>\n"
        )
      )

      # The end of the definitions

      nfs_contents =
        # frame label
        Frame(
          _("NFS Server"),
          VBox(
            VSpacing(0.2),
            RadioButtonGroup(
              Id(:rbgroup),
              # radio button label
              VBox(
                Left(
                  RadioButton(
                    Id(:servyes),
                    Opt(:notify),
                    _("&Start"),
                    start_nfs_server
                  )
                ),
                #radio button label
                Left(
                  RadioButton(
                    Id(:servno),
                    Opt(:notify),
                    _("Do &Not Start"),
                    !start_nfs_server
                  )
                )
              )
            ),
            VSpacing(0.2)
          )
        )
      fw_contents =
        # frame label
        VBox(
          VSpacing(0.2),
          Ops.get_term(fw_cwm_widget, "custom_widget", Empty()),
          VSpacing(0.2)
        )

      nfsv4_contents = Frame(
        _("Enable NFSv4"),
        VBox(
          VSpacing(0.2),
          Left(
            CheckBox(
              Id(:enable_nfsv4),
              Opt(:notify),
              _("Enable NFS&v4"),
              enable_nfsv4
            )
          ),
          VSpacing(0.2),
          TextEntry(Id(:domain), _("Enter NFSv4 do&main name:"), domain),
          VSpacing(0.2)
        )
      )


      sec_contents = Left(
        CheckBox(
          Id(:nfs_security),
          Opt(:notify),
          _("Enable &GSS Security"),
          nfs_security
        )
      )


      contents = HVSquash(
        VBox(
          nfs_contents,
          VSpacing(1),
          fw_contents,
          VSpacing(1),
          nfsv4_contents,
          VSpacing(1),
          sec_contents
        )
      )

      # dialog title
      Wizard.SetContents(
        _("NFS Server Configuration"),
        contents,
        help_text,
        true,
        true
      )
      Wizard.DisableBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      # initialize the widget (set the current value)
      CWMFirewallInterfaces.OpenFirewallInit(fw_cwm_widget, "")

      if enable_nfsv4
        UI.ChangeWidget(Id(:domain), :Enabled, true)
      else
        UI.ChangeWidget(Id(:domain), :Enabled, false)
      end

      event = nil
      ret = nil
      begin
        start_nfs_server = UI.QueryWidget(Id(:rbgroup), :CurrentButton) == :servyes
        if !start_nfs_server
          Wizard.SetNextButton(:next, Label.OKButton)
        else
          Wizard.RestoreNextButton
          Wizard.SetFocusToNextButton
        end

        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        if ret == :enable_nfsv4
          enable_nfsv4 = UI.QueryWidget(Id(:enable_nfsv4), :Value) == true
          NfsServer.enable_nfsv4 = enable_nfsv4
          if enable_nfsv4
            UI.ChangeWidget(Id(:domain), :Enabled, true)
          else
            UI.ChangeWidget(Id(:domain), :Enabled, false)
          end
        end

        if ret == :nfs_security
          nfs_security = UI.QueryWidget(Id(:nfs_security), :Value) == true
          NfsServer.nfs_security = nfs_security
        end
        ret = :abort if ret == :cancel

        # handle the events, enable/disable the button, show the popup if button clicked
        CWMFirewallInterfaces.OpenFirewallHandle(fw_cwm_widget, "", event)
        changed = CWMFirewallInterfaces.OpenFirewallModified("") ||
          start_nfs_server != NfsServer.start # "" because method doesn't use parameter at all, nice :(

        ret = :again if ret == :abort && changed && !Popup.ReallyAbort(changed)
      end while ret != :back && ret != :next && ret != :abort

      if ret == :next
        # grab current settings, store them to firewalld::
        CWMFirewallInterfaces.OpenFirewallStore(fw_cwm_widget, "", event)
        NfsServer.start = start_nfs_server
        NfsServer.domain = Convert.to_string(
          UI.QueryWidget(Id(:domain), :Value)
        )
        return :finish if !start_nfs_server
      end

      Wizard.RestoreBackButton
      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end

    # Exports dialog itself
    # @return `back, `abort, `next
    def ExportsDialog
      Wizard.SetScreenShotName("nfs-server-2-exports")

      # Help, part 1 of 4
      help_text = _(
        "<P>The upper box contains all the directories to export.\n" +
          "If a directory is selected, the lower box shows the hosts allowed to\n" +
          "mount this directory.</P>\n"
      )

      # Help, part 2 of 4
      help_text +=
        _(
          "<P><b>Host Wild Card</b> sets which hosts can access the selected directory.\n" +
            "It can be a single host, groups, wild cards, or\n" +
            "IP networks.</P>\n"
        )

      # Help, part 3 of 4
      help_text +=
          _(
            "<p>Enter an asterisk (<tt>*</tt>) instead of a name to specify all hosts.</p>"
          )

      # Help, part 4 of 4
      help_text +=
        _("<P>Refer to <tt>man exports</tt> for more information.</P>\n")

      exports = deep_copy(NfsServer.exports)

      contents = VBox()

      contents = Builtins.add(
        contents,
        ReplacePoint(Id(:exportsrep), ExportsSelBox(exports))
      )

      # push button label
      contents = Builtins.add(
        contents,
        HBox(
          PushButton(Id(:mpnewbut), Opt(:key_F3), _("Add &Directory")),
          # push button label
          PushButton(Id(:mpeditbut), Opt(:key_F4), _("&Edit")),
          # push button label
          PushButton(Id(:mpdelbut), Opt(:key_F5), _("De&lete"))
        )
      )
      # push button label
      contents = Builtins.add(
        contents,
        VBox(
          Left(Label(Id(:allowedlab), Opt(:hstretch), "")),
          Table(
            Id(:allowedtab),
            Opt(:notify, :immediate),
            # table header
            Header(
              _("Host Wild Card") + "  ",
              # table header
              _("Options") + "  "
            ),
            []
          )
        )
      )
      # push button label

      contents = Builtins.add(
        contents,
        HBox(
          PushButton(Id(:alwnewbut), _("Add &Host")),
          # push button label
          PushButton(Id(:alweditbut), _("Ed&it")),
          # push button label
          PushButton(Id(:alwdelbut), _("Dele&te"))
        )
      )


      Wizard.SetContentsButtons(
        # dialog title
        _("Directories to Export"),
        contents,
        help_text,
        Label.BackButton,
        Label.FinishButton
      )
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      event = nil
      ret = nil
      simulated = nil # simulated user input
      oldmp = nil
      # preselect an item - convenience, button enabling
      if Ops.greater_than(Builtins.size(exports), 0)
        UI.ChangeWidget(
          Id(:exportsbox),
          :CurrentItem,
          Ops.get_string(exports, [0, "mountpoint"], "")
        )
      end
      begin
        mountpoint = current_export_dir

        anymp = mountpoint != nil

        UI.ChangeWidget(Id(:mpeditbut), :Enabled, anymp)
        UI.ChangeWidget(Id(:mpdelbut), :Enabled, anymp)
        UI.ChangeWidget(Id(:alwnewbut), :Enabled, anymp)
        if mountpoint != oldmp
          mountpoint = "" if mountpoint == nil
          UI.ChangeWidget(Id(:allowedlab), :Value, mountpoint)
          oldmp = mountpoint
          allowed = FindAllowed(exports, mountpoint)
          UI.ChangeWidget(
            Id(:allowedtab),
            :Items,
            AllowedTableItems(allowed != nil ? allowed : [])
          )
        end
        anyalw = UI.QueryWidget(Id(:allowedtab), :CurrentItem) != nil
        UI.ChangeWidget(Id(:alweditbut), :Enabled, anyalw)
        UI.ChangeWidget(Id(:alwdelbut), :Enabled, anyalw)

        # Kludge, because a `Table still does not have a shortcut.
        UI.SetFocus(Id(:allowedtab))

        # simulated input,
        # used for `alweditbut afted `mpnewbut
        if simulated == nil
          event = UI.WaitForEvent
          ret = Ops.get(event, "ID")
          ret = :abort if ret == :cancel
        else
          ret = deep_copy(simulated)
          simulated = nil
        end

        if ret == :mpnewbut
          mountpoint2 = GetDirectory(nil, exports)

          if mountpoint2 != nil
            default_allowed = [ "*(%s)" % GetDefaultOpts(exports, "*") ]
            exports = Builtins.add(
              exports,
              { "mountpoint" => mountpoint2, "allowed" => default_allowed }
            )
            UI.ReplaceWidget(Id(:exportsrep), ExportsSelBox(exports))
            UI.ChangeWidget(Id(:exportsbox), :CurrentItem, mountpoint2)
            simulated = :alweditbut
          end
        elsif ret == :mpeditbut
          mp = current_export_dir

          if mp != nil
            mountpoint2 = GetDirectory(mp, Builtins.filter(exports) do |ent|
              Ops.get_string(ent, "mountpoint", "") != mp
            end)

            if mountpoint2 != nil
              exports = Builtins.maplist(exports) do |ent|
                tmp = Ops.get_string(ent, "mountpoint", "")
                next Builtins.add(ent, "mountpoint", mountpoint2) if tmp == mp
                deep_copy(ent)
              end

              UI.ReplaceWidget(Id(:exportsrep), ExportsSelBox(exports))

              UI.ChangeWidget(Id(:exportsbox), :CurrentItem, mountpoint2)
            end
          end
        elsif ret == :mpdelbut
          mountpoint2 = current_export_dir

          exports = Builtins.filter(exports) do |entry|
            Ops.get_string(entry, "mountpoint", "") != mountpoint2
          end if mountpoint2 != nil

          UI.ReplaceWidget(Id(:exportsrep), ExportsSelBox(exports))
          if Ops.greater_than(Builtins.size(exports), 0)
            UI.ChangeWidget(
              Id(:exportsbox),
              :CurrentItem,
              Ops.get_string(exports, [0, "mountpoint"], "")
            )
          end
        elsif ret == :alwnewbut
          mountpoint2 = current_export_dir

          if mountpoint2 != nil
            allowed = FindAllowed(exports, mountpoint2)

            hostopt = GetAllowedHosts(
              exports,
              mountpoint2,
              nil,
              nil,
              allowed,
              false
            )
            if hostopt != nil
              allowed = Builtins.add(
                allowed,
                Ops.add(
                  Ops.add(
                    Ops.add(Ops.get(hostopt, 0, ""), "("),
                    Ops.get(hostopt, 1, "")
                  ),
                  ")"
                )
              )
              exports = ReplaceInExports(exports, mountpoint2, allowed)

              UI.ChangeWidget(
                Id(:allowedtab),
                :Items,
                AllowedTableItems(allowed)
              )
            end
          end
        elsif ret == :alweditbut
          mountpoint2 = current_export_dir

          if mountpoint2 != nil
            allowed = FindAllowed(exports, mountpoint2)
            hosts = ""
            opts = ""
            if allowed != nil
              alw_no = Convert.to_integer(
                UI.QueryWidget(Id(:allowedtab), :CurrentItem)
              )
              if alw_no != nil
                ho = AllowedToHostsOpts(Ops.get(allowed, alw_no, ""))
                hosts = Ops.get(ho, 0, "")
                opts = Ops.get(ho, 1, "")
              end
              allowed = Builtins.remove(allowed, alw_no)
            end
            hostopt = GetAllowedHosts(
              exports,
              mountpoint2,
              hosts,
              opts,
              allowed,
              true
            )
            if hostopt != nil
              allowed = Builtins.add(
                allowed,
                Ops.add(
                  Ops.add(
                    Ops.add(Ops.get(hostopt, 0, ""), "("),
                    Ops.get(hostopt, 1, "")
                  ),
                  ")"
                )
              )
              exports = ReplaceInExports(exports, mountpoint2, allowed)

              UI.ChangeWidget(
                Id(:allowedtab),
                :Items,
                AllowedTableItems(allowed)
              )
            end
          end
        elsif ret == :alwdelbut
          mountpoint2 = current_export_dir

          if mountpoint2 != nil
            allowed = FindAllowed(exports, mountpoint2)
            alwno = Convert.to_integer(
              UI.QueryWidget(Id(:allowedtab), :CurrentItem)
            )
            if allowed != nil && alwno != nil
              allowed = Builtins.remove(allowed, alwno)
              exports = Builtins.maplist(exports) do |entry|
                if Ops.get_string(entry, "mountpoint", "") == mountpoint2
                  entry = Builtins.add(entry, "allowed", allowed)
                end
                deep_copy(entry)
              end

              UI.ChangeWidget(
                Id(:allowedtab),
                :Items,
                AllowedTableItems(allowed)
              )
            end
          end
        elsif ret == :abort && !Popup.ReallyAbort(true)
          ret = :again
        end
      end while ret != :back && ret != :next && ret != :abort

      NfsServer.exports = deep_copy(exports) if ret == :next

      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end


    # Whole configuration of NfsServer but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def NfsServerAutoSequence
      _Aliases = { "begin" => lambda { BeginDialog() }, "exports" => lambda do
        ExportsDialog()
      end }

      _Sequence = {
        "ws_start" => "begin",
        "begin"    => { :next => "exports", :finish => :next, :abort => :abort },
        "exports"  => { :next => :next, :abort => :abort }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.NFSServer")

      ret = Sequencer.Run(_Aliases, _Sequence)
      UI.CloseDialog
      ret
    end
  end
end
