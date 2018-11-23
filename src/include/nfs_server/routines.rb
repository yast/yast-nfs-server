# encoding: utf-8

# File:
#   routines.ycp
#
# Module:
#   Configuration of nfs server
#
# Summary:
#   Network NFS routines
#
# Authors:
#   Jan Holesovsky <kendy@suse.cz>
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Network NFS routines
#
module Yast
  module NfsServerRoutinesInclude
    def initialize_nfs_server_routines(include_target)
      textdomain "nfs_server"
      Yast.import "NfsServer"
      Yast.import "Popup"
      Yast.import "Report"


      # nfs-utils-1.0.1 gives a warning
      # if neither of sync, async is specified.
      #
      # no_subtree_check:
      #  http://nfs.sourceforge.net/#faq_c7
      #  nfs-utils-1.1.0, will switch the default from subtree_check
      #  to no_subtree_check (#233709)
      @default_options = "ro,root_squash,sync,no_subtree_check"
    end

    # Split the allowed host specification
    # @param [String] hosts	"hosts(opts)"
    # @return		["hosts", "opts"]
    def AllowedToHostsOpts(hosts)
      brpos = Builtins.findfirstof(hosts, "(")
      opts = ""
      if brpos != nil
        opts = Builtins.substring(hosts, Ops.add(brpos, 1))
        hosts = Builtins.substring(hosts, 0, brpos)

        brpos = Builtins.findfirstof(opts, ")")
        opts = Builtins.substring(opts, 0, brpos) if brpos != nil
      end
      [hosts, opts]
    end

    # @param [Array<String>] allowed	a list of allowed host specifications
    # @return		a ui table list of items
    # @example AllowedTableItems (["*.local.domain(ro)", "@trusted(rw)"])
    def AllowedTableItems(allowed)
      allowed = deep_copy(allowed)
      count = 0
      Builtins.maplist(allowed) do |str|
        sp = AllowedToHostsOpts(str)
        it = Item(
          Id(count),
          Ops.add(Ops.get(sp, 0, ""), " "),
          Ops.add(Ops.get(sp, 1, ""), " ")
        )
        count = Ops.add(count, 1)
        deep_copy(it)
      end
    end

    # Find entry in exports according to the mountpoint
    # @param [Array<Hash>] exports	list of exports
    # @param [String] mp	mount point
    # @return		a list of allowed host specifications or nil if not found
    def FindAllowed(exports, mp)
      exports = deep_copy(exports)
      flt = Builtins.filter(exports) do |ent|
        Ops.get_string(ent, "mountpoint", "") == mp
      end
      return nil if flt == nil || Builtins.size(flt) == 0

      Convert.convert(
        Ops.get(flt, [0, "allowed"]),
        :from => "any",
        :to   => "list <string>"
      )
    end


    # Find out whether client representations are related
    # @param [String] clntexpr1	first client representation to which check is being made
    # @param [String] clntexpr2	another client representatio against which the check is done
    # @return		1, if clntexpr1 is contained in clntexpr2 and -1, if otherway round,
    #                  and 0 if they are independent
    # @example		1.2.3.4 (is contained in) 1.*.3.4,
    #.abc.com (contains)xyz.abc.com and xyz.* and abc.com are independent
    #
    # FIXME This is not too intelligent. Ideally a while loop with matching '*' is required.
    # 1) Doesn't look default name domain.
    # 2) Doesn't know how to deal with *.abc.* ; only single '*' please :(
    def ClientRelated(clntexpr1, clntexpr2)
      pos = Builtins.findfirstof(clntexpr2, "*")
      len = Builtins.size(clntexpr2)

      clntexpr2 = Builtins.tolower(clntexpr2)
      clntexpr1 = Builtins.tolower(clntexpr1)

      if pos == nil
        pos = Builtins.findfirstof(clntexpr1, "*")
        return 0 if pos == nil # FIXME We must continue investigating with name/ip resolution
        # Both expressions not having *, doesn't mean they are not
        # related.
        return Ops.multiply(-1, ClientRelated(clntexpr2, clntexpr1))
      end

      return 1 if clntexpr2 == "*"
      return 1 if clntexpr1 == clntexpr2

      if pos == Ops.subtract(len, 1) # expressions of type abc.xyz.*
        check = Builtins.substring(clntexpr2, 0, pos)
        matchpos = Builtins.findfirstof(clntexpr1, check)
        return 1 if matchpos == 0
      elsif pos == 0
        check = Builtins.substring(clntexpr2, 1)
        matchpos = Builtins.findfirstof(clntexpr1, check)
        right = Builtins.substring(clntexpr1, matchpos)
        return 1 if check == right
      else
        # expressions of type abc.*.xyz
        checkleft = Builtins.substring(clntexpr2, 0, pos)
        matchpos = Builtins.findfirstof(clntexpr1, checkleft)
        if matchpos == 0
          checkright = Builtins.substring(clntexpr2, Ops.add(pos, 1))
          matchpos2 = Builtins.findfirstof(clntexpr1, checkright)
          right = Builtins.substring(clntexpr1, matchpos2)

          return 1 if checkright == right
        end
      end

      0
    end

    # Give out appropriate default options
    # @param [Array<Hash>] exports	list of exports
    # @param [String] client	some string representation of the client (*, *.domain, ip address)
    # @return		a comma separated default options string, that is most appropriate
    def GetDefaultOpts(exports, client)
      return @default_options
    end



    # Report the first error that is encountered while checking for Unique NFSv4
    # psuedofilesystem root.
    # @param [Array<Hash>] exports	list of exports
    # @param [String] expath	the exported filesystem path
    # @param [String] client	string representing a client (*, *.domain, ip address etc)
    # @param [String] eopts	comma separated string of export options
    # @return		the first error encountered or nil
    def CheckUniqueRootForClient(exports, expath, client, eopts)
      exports = deep_copy(exports)
      exportpath = ""
      errorstring = nil
      clientrelation = 0

      if !Builtins.issubstring(eopts, "fsid=0") # Then no need to check for conflict.
        return nil
      end

      Builtins.foreach(
        Convert.convert(
          exports,
          :from => "list <map>",
          :to   => "list <map <string, any>>"
        )
      ) do |entry|
        exportpath = Ops.get_string(entry, "mountpoint", "")
        Builtins.foreach(
          Convert.convert(
            Ops.get(entry, "allowed") { ["()"] },
            :from => "any",
            :to   => "list <string>"
          )
        ) do |hostops|
          opts = ""
          clientexpr = ""
          pos = Builtins.findfirstof(hostops, "(")
          if pos != nil
            opts = Builtins.substring(hostops, Ops.add(pos, 1))
            clientexpr = Builtins.substring(hostops, 0, pos)

            pos = Builtins.findfirstof(opts, ")")
            opts = Builtins.substring(opts, 0, pos) if pos != nil
          end
          clientrelation = ClientRelated(client, clientexpr)
          if clientrelation != 0
            if Builtins.issubstring(opts, "fsid=0")
              if exportpath != expath
                if clientrelation == 1
                  errorstring = Builtins.sformat(
                    _(
                      "%3 and %4 are both exported with the option fsid=0\nfor the same client '%1' (contained in '%2')"
                    ),
                    client,
                    clientexpr,
                    expath,
                    exportpath
                  )
                else
                  errorstring = Builtins.sformat(
                    _(
                      "%3 and %4 are both exported with the option fsid=0\nfor the same client '%1' (contained in '%2')"
                    ),
                    clientexpr,
                    client,
                    expath,
                    exportpath
                  )
                end
                raise Break
              end
            end
          end
        end
        raise Break if errorstring != nil
      end

      errorstring
    end


    # @param [Array<Hash>] exports	list of exports
    # @return		a ui table list of mountpoints, id'ed by themselves
    def ExportsItems(exports)
      exports = deep_copy(exports)
      Builtins.maplist(exports) do |entry|
        str = Ops.get_string(entry, "mountpoint", "")
        Item(Id(str), Ops.add(str, " "))
      end
    end


    # @param entry list of "host(opts)" strings
    # @return	[String] a comma-separated list of bind target paths.
    def getbindpaths(entry)
      entry = deep_copy(entry)
      exportpath = Ops.get_string(entry, "mountpoint", "")
      clients = Convert.convert(
        Ops.get(entry, "allowed") { ["()"] },
        :from => "any",
        :to   => "list <string>"
      )
      bindpaths = ""
      paths = []
      Builtins.foreach(clients) do |hostopts|
        pos = Builtins.findfirstof(hostopts, "(")
        opts = Builtins.substring(hostopts, Ops.add(pos, 1))
        clientexpr = Builtins.substring(hostopts, 0, pos)
        bindpath = ""
        pos = Builtins.findfirstof(opts, ")")
        opts = Builtins.substring(opts, 0, pos) if pos != nil
        if opts == ""
          Builtins.y2error(
            "Your /etc/exports file has errors. The export path %1 has no export options specified.",
            exportpath
          )
        end
        pos = Builtins.search(opts, "bind=")
        if pos != nil
          bindpath = Builtins.substring(opts, Ops.add(pos, 5))
          pos = Builtins.findfirstof(bindpath, ",")
          bindpath = Builtins.substring(bindpath, 0, pos) if pos != nil
        end
        paths = Builtins.prepend(paths, bindpath) if bindpath != ""
      end
      bindpaths = Builtins.mergestring(paths, ",") if Builtins.size(paths) != 0


      bindpaths
    end


    # @param [Array<Hash>] exports	list of exports
    # @return		a ui table list of mountpoints and the corresponding
    #			bindmount targets, if any.
    def ExportsRows(exports)
      exports = deep_copy(exports)
      Builtins.maplist(exports) do |entry|
        exportpath = Ops.get_string(entry, "mountpoint", "")
        bindpaths = getbindpaths(entry)
        Item(Id(exportpath), Ops.add(exportpath, " "), bindpaths)
      end
    end

    # Returns currently selected directory configured for export via NFS.
    def current_export_dir
      UI.QueryWidget(Id(:exportsbox), :CurrentItem)
    end


    # @param [Array<Hash>] exports	list of exports
    # @return		a SelectionBox for the mountpoints, `id(`exportsbox) containing
    #			list of exported directory paths.
    def ExportsSelBox(exports)
      return SelectionBox(
        Id(:exportsbox),
        Opt(:notify),
        # selection box label
        _("Dire&ctories"),
        ExportsItems(exports)
      )
    end

    # Check for the validity of client specification:
    # fewer than 70 chars, no blanks.
    # If invalid, a message is displayed.
    # @param [String] name	options
    # @return		whether valid
    def CheckNoSpaces(name)
      if Ops.less_than(Builtins.size(name), 70) &&
          Builtins.findfirstof(name, " \t") == nil
        return true
      else
        # error popup message
        Report.Message(
          Builtins.sformat(
            _(
              "The wild card or options string is invalid.\n" +
                "It must be shorter than 70 characters and it\n" +
                "must not contain spaces.\n"
            )
          )
        )
      end
      false
    end


    # Check for the validity of export options:
    # [A-Za-z0-9=/.:,_-]*
    # If invalid, a message is displayed.
    # @param [String] options	spaces and parentheses already removed
    # @return		whether valid
    def CheckExportOptions(options)
      # colon is allowed for sec= option, see man 5 exports
      if Builtins.regexpmatch(options, "[^A-Za-z0-9=/.:,_-]")
        # error popup message
        Report.Error(
          _(
            "Invalid option.\nOnly letters, digits, and the characters =/.:,_- are allowed."
          )
        )
        return false
      end
      true
    end


    # Check for the validity of export options: only those listed in
    # exports(5) are accepted.
    # Unused - to allow not only nfs-utils but also nfs-server.
    # If invalid, a message is displayed.
    # @param [String] options	spaces and parentheses already removed
    # @return		whether valid
    def CheckExportOptions_strict(options)
      o1 = [
        "secure",
        "insecure",
        "rw",
        "ro",
        "sync",
        "async",
        "no_wdelay",
        "wdelay",
        "nohide",
        "hide",
        "no_subtree_check",
        "subtree_check",
        "insecure_locks",
        "secure_locks",
        "no_auth_nlm",
        "auth_nlm",
        "root_squash",
        "no_root_squash",
        "all_squash",
        "no_all_squash"
      ]
      o_value = ["anonuid", "anongid"]
      opts = Builtins.splitstring(options, ",")

      ret = true
      opts = Builtins.filter(opts) { |e| !Builtins.contains(o1, e) }
      Builtins.foreach(opts) do |e|
        opt = Builtins.splitstring(e, "=")
        if !Builtins.contains(o_value, Ops.get(opt, 0, ""))
          # error popup message
          Popup.Error(Builtins.sformat(_("Unknown option: '%1'"), e))
          ret = false
        elsif Builtins.size(opt) != 2 ||
            !Builtins.regexpmatch(Ops.get(opt, 1, ""), "[0-9]+")
          # error popup message
          Popup.Error(Builtins.sformat(_("Invalid option: '%1'"), e))
          ret = false
        end
      end
      ret
    end

    # Check for suspicious allowed lists and warn the user.
    # Like "host(rw, sync)" with the space.
    def CheckSyntaxErrors(exports)
      exports = deep_copy(exports)
      bad_shares = {}
      Builtins.foreach(exports) do |entry|
        Builtins.foreach(
          Convert.convert(
            Ops.get(entry, "allowed") { ["()"] },
            :from => "any",
            :to   => "list <string>"
          )
        ) do |client|
          if Builtins.search(client, "(") == nil ||
              Builtins.search(client, ")") == nil
            Ops.set(bad_shares, Ops.get_string(entry, "mountpoint", "?"), true)
          end
        end
      end
      bad_shares_l = Builtins.maplist(bad_shares) { |s, d| s }
      bad_shares_s = Builtins.mergestring(bad_shares_l, ", ")
      if bad_shares_s != ""
        # %1 is a list of exported paths
        Report.Warning(
          Builtins.sformat(
            _(
              "There are unbalanced parentheses in export options\n" +
                "for %1.\n" +
                "Likely, there is a spurious whitespace in the configuration file.\n"
            ),
            bad_shares_s
          )
        )
      end

      nil
    end

    # Replaces 'allowed' list in exports (for specified mountpoint)
    # @param [Array<Hash{String => Object>}] exports		exports list
    # @param [String] mountpoint	mount point
    # @param [Array<String>] allowed		new allowed host list for that mout point
    # @return			modified exports list
    def ReplaceInExports(exports, mountpoint, allowed)
      exports = deep_copy(exports)
      allowed = deep_copy(allowed)
      Builtins.maplist(exports) do |entry|
        if Ops.get_string(entry, "mountpoint", "") == mountpoint
          entry = Builtins.add(entry, "allowed", allowed)
        end
        deep_copy(entry)
      end
    end
  end
end
