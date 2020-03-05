require_relative "test_helper"

class C < Yast::Module
  def initialize
    Yast.include self, "nfs_server/routines.rb"
  end
end

describe "NfsServer::Routines" do
  subject { C.new }

  let(:exports) do
    [
      {
        "allowed" => ["proj*.local.domain(rw)"],
        "mountpoint" => "/projects"
      },
      {
        "allowed"    => ["*.local.domain(ro)", "@trusted(rw)"],
        "mountpoint" => "/usr"
      },
      {
        "allowed" => ["(ro,insecure,all_squash)"],
        "mountpoint" => "/pub"
      }
    ]
  end

  describe "#AllowedToHostsOpts" do
    it "returns a pair with host and options" do
      expect(subject.AllowedToHostsOpts("host.com(options)")).to eq ["host.com", "options"]
    end

    it "returns a pair with host and empty string when no options are specified" do
      expect(subject.AllowedToHostsOpts("host.com")).to eq ["host.com", ""]
    end

    it "returns pair with empty strings when empty string is passed" do
      expect(subject.AllowedToHostsOpts("")).to eq ["", ""]
    end

    it "can handle missing ending bracket" do
      expect(subject.AllowedToHostsOpts("host.com(options")).to eq ["host.com", "options"]
    end

    it "returns only opening bracket when double brackets is used" do
      expect(subject.AllowedToHostsOpts("host.com((options))")).to eq ["host.com", "(options"]
    end
  end

  describe "#AllowedTableItems" do
    it "creates table items with item number as id from allow host specifications" do
      expect(subject.AllowedTableItems(["*.local.domain(ro)", "@trusted(rw)"])).to eq(
        [
          Item(Id(0), "*.local.domain ", "ro "),
          Item(Id(1), "@trusted ", "rw ")
        ]
      )
    end

    it "returns empty list when empty array is passed" do
      expect(subject.AllowedTableItems([])).to eq []
    end
  end

  describe "#FindAllowed" do
    it "returns associated allowed for given mount point" do
      expect(subject.FindAllowed(exports, "/pub")).to eq ["(ro,insecure,all_squash)"]
    end

    it "returns nil if mount point is not found" do
      expect(subject.FindAllowed(exports, "/hackers_heaven")).to eq nil
    end
  end

  describe "#ExportsItems" do
    it "returns list of items with mount points" do
      expect(subject.ExportsItems(exports)).to eq [
        Item(Id("/projects"), "/projects "),
        Item(Id("/usr"), "/usr "),
        Item(Id("/pub"), "/pub ")
      ]
    end
  end

  describe "#ExportsSelBox" do
    it "returns selection box with mount points as selection" do
      expect(subject.ExportsSelBox(exports)).to eq SelectionBox(
        Id(:exportsbox),
        Opt(:notify),
        "Dire&ctories",
        [
          Item(Id("/projects"), "/projects "),
          Item(Id("/usr"), "/usr "),
          Item(Id("/pub"), "/pub ")
        ]
      )
    end
  end

  describe "#ReplaceInExports" do
    it "returns copy of exports with new allowed for given mount point" do
      expect(subject.ReplaceInExports(exports, "/usr", ["*.localdomain(ro)"])).to eq(
        [
          {
            "allowed" => ["proj*.local.domain(rw)"],
            "mountpoint" => "/projects"
          },
          {
            "allowed"    => ["*.localdomain(ro)"],
            "mountpoint" => "/usr"
          },
          {
            "allowed" => ["(ro,insecure,all_squash)"],
            "mountpoint" => "/pub"
          }
        ]
      )
    end

    it "returns unmodified exports if mount point not found" do
      expect(subject.ReplaceInExports(exports, "/test", ["*.localdomain(ro)"])).to eq exports
    end
  end

  describe "#CheckNoSpaces" do
    it "returns true if parameter is valid" do
      expect(subject.CheckNoSpaces("test")).to eq true
    end

    it "returns false and Reports if name contain space" do
      [" space_before", "space inside", "space_after ", "tab\tulator"].each do |name_with_space|
        expect(Yast::Report).to receive(:Message)
        expect(subject.CheckNoSpaces(name_with_space)).to eq false
      end
    end

    it "returns false and Reports if name is 70 chars or more" do
      expect(Yast::Report).to receive(:Message)
      expect(subject.CheckNoSpaces("a" * 70)).to eq false
    end
  end

  describe "#CheckExportOptions" do
    it "returns true if parameter is valid" do
      expect(subject.CheckExportOptions("test")).to eq true
    end

    it "returns false and Reports if name forbidden character" do
      ["invalid:options <> ?"].each do |invalid_options|
        expect(Yast::Report).to receive(:Error)
        expect(subject.CheckExportOptions(invalid_options)).to eq false
      end
    end
  end

  describe "#CheckExportOptions_strict" do
    it "returns true if parameter is valid and known" do
      expect(subject.CheckExportOptions_strict("ro,insecure,all_squash")).to eq true
      all_known = "secure,insecure,rw,ro,sync,async,no_wdelay,wdelay,nohide,hide,no_subtree_check,subtree_check,insecure_locks,secure_locks,no_auth_nlm,auth_nlm,root_squash,no_root_squash,all_squash,no_all_squash"
      expect(subject.CheckExportOptions_strict(all_known)).to eq true
    end

    it "returns false and Popup error if name contains forbidden character or unknown" do
      ["ro,some_invalid", "invalid:chars <> ?"].each do |invalid_options|
        expect(Yast::Popup).to receive(:Error)
        expect(subject.CheckExportOptions_strict(invalid_options)).to eq false
      end
    end
  end
end
