require_relative "test_helper"

Yast.import "NfsServer"

describe Yast::NfsServer do
  subject { Yast::NfsServer }

  before do
    allow(Yast::SCR).to receive(:Read)
    allow(Yast::SCR).to receive(:Write).and_return(true)
    allow(Yast::SCR).to receive(:Execute)
    allow(Yast::Service).to receive(:Enabled).and_return(false)
    allow(Yast::Service).to receive(:active?).and_return(false)
    allow(Yast::Service).to receive(:Start)
    allow(Yast::Service).to receive(:Restart)
    allow(Yast::Service).to receive(:Stop)
    allow(Yast::Service).to receive(:Enable)
    allow(Yast::Service).to receive(:Disable)
    allow(Y2Firewall::Firewalld.instance).to receive(:read)

    subject.main
  end

  describe ".Read" do
    it "reads service status" do
      allow(Yast::Service).to receive(:Enabled).and_return(true)

      subject.Read
      expect(subject.start).to eq true
    end

    it "reads list of exports" do
      exports = [{"mountpoint" => "/test1"}]
      allow(Yast::SCR).to receive(:Read).with(path(".etc.exports")).and_return(exports)

      subject.Read
      expect(subject.exports).to eq exports
    end

    it "reads nfs4 enablement" do
      allow(Yast::SCR).to receive(:Read).with(path(".sysconfig.nfs.NFS4_SUPPORT")).and_return("yes")

      subject.Read
      expect(subject.enable_nfsv4).to eq true
    end

    it "reads nfs security flag" do
      allow(Yast::SCR).to receive(:Read).with(path(".sysconfig.nfs.NFS_SECURITY_GSS")).and_return("yes")

      subject.Read
      expect(subject.nfs_security).to eq true
    end

    context "nfs4 is enabled" do
      it "reads domain from idmapd" do
        allow(Yast::SCR).to receive(:Read).with(path(".sysconfig.nfs.NFS4_SUPPORT")).and_return("yes")
        allow(Yast::SCR).to receive(:Read).with(path(".etc.idmapd_conf.value.General.Domain")).and_return("SUSE")

        subject.Read
        expect(subject.domain).to eq "SUSE"
      end
    end

    it "reads firewall settings" do
      expect(Y2Firewall::Firewalld.instance).to receive(:read)

      subject.Read
    end
  end

  describe ".Write" do
    it "writes nfs4 enablement" do
      subject.enable_nfsv4 = false

      expect(Yast::SCR).to receive(:Write).with(path(".sysconfig.nfs.NFS4_SUPPORT"), "no")

      subject.Write
    end

    it "writes nfs security flag" do
      subject.nfs_security = true

      expect(Yast::SCR).to receive(:Write).with(path(".sysconfig.nfs.NFS_SECURITY_GSS"), "yes")

      subject.Write
    end

    context "nfs4 is enabled" do
      it "writes domain to idmapd" do
        expect(Yast::SCR).to receive(:Write).with(path(".sysconfig.nfs.NFS4_SUPPORT"), "yes")
        expect(Yast::SCR).to receive(:Write).with(path(".etc.idmapd_conf.value.General.Domain"), "SUSE")

        subject.domain = "SUSE"
        subject.enable_nfsv4 = true

        subject.Write
      end
    end

    it "creates all directories used as mount point in exports" do
      subject.exports = [{"mountpoint" => "/test1"}]

      expect(Yast::SCR).to receive(:Execute).with(path(".target.mkdir"), "/test1")

      subject.Write
    end

    it "writes exports" do
      subject.exports = [{"mountpoint" => "/test1"}]

      expect(Yast::SCR).to receive(:Write).with(path(".etc.exports"), subject.exports)

      subject.Write
    end

    context "start flag is set to false" do
      before do
        subject.start = false
      end

      it "stops nfs-server service unless write_only flag is true" do
        expect(Yast::Service).to receive(:Stop).with("nfs-server")
        subject.write_only = false

        subject.Write

        expect(Yast::Service).to_not receive(:Stop).with("nfs-server")
        subject.write_only = true

        subject.Write
      end

      it "disables nfs-server service" do
        expect(Yast::Service).to receive(:Disable).with("nfs-server")

        subject.Write
      end
    end

    context "start flag is set to true" do
      before do
        subject.start = true
      end

      it "enables rpcbind service" do
        expect(Yast::Service).to receive(:Enable).with("rpcbind")

        subject.Write
      end

      it "enables nfs-server service" do
        expect(Yast::Service).to receive(:Enable).with("nfs-server")

        subject.Write
      end

      context "nfs security flag is set to false" do
        before do
          subject.nfs_security = false
        end

        it "stops rpc-svcgssd if running" do
          allow(Yast::Service).to receive(:active?).with("rpc-svcgssd").and_return(true)
          expect(Yast::Service).to receive(:Stop).with("rpc-svcgssd")

          subject.Write
        end
      end

      context "nfs security flag is set to true" do
        before do
          subject.nfs_security = true
        end

        it "restarts rpc-svcgssd if running" do
          allow(Yast::Service).to receive(:active?).with("rpc-svcgssd").and_return(true)
          expect(Yast::Service).to receive(:Restart).with("rpc-svcgssd")

          subject.Write
        end

        it "starts rpc-svcgssd if not running" do
          allow(Yast::Service).to receive(:active?).with("rpc-svcgssd").and_return(false)
          expect(Yast::Service).to receive(:Start).with("rpc-svcgssd")

          subject.Write
        end
      end

      context "write only flag is set to false" do
        before do
          subject.write_only = false
        end

        it "ensures rpcbind is running" do
          allow(Yast::Service).to receive(:active?).with("rpcbind").and_return(false)
          expect(Yast::Service).to receive(:Start).with("rpcbind")

          subject.Write
        end

        it "restarts nfs-server services" do
          expect(Yast::Service).to receive(:Restart).with("nfs-server")

          subject.Write
        end
      end
    end
  end
end
