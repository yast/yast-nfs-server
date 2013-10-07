YaST NFS Server Module
======================

The YaST NFS Server module manages configuration of an
[NFS](http://en.wikipedia.org/wiki/Network_File_System) server. It's a part of
[YaST](https://en.opensuse.org/Portal:YaST) — installation and configuration
tool for [openSUSE](http://www.opensuse.org/) and SUSE Linux Enterprise (SLE).

<p align="center">
  <img src="http://imgbin.org/images/15301.png" alt="YaST NFS Server Module">
</p>

Features
--------

  * A
  * B
  * C

Installation
------------

To install the latest stable version on openSUSE or SLE, use zypper:

    $ zypper install yast2-nfs-server

You can also install the lastest development version. To do that, you need to
add the [YaST:Head](https://build.opensuse.org/project/show/YaST:Head)
repository to your system first (you may need to change the `openSUSE_12.3` part
of the repository URL according to the system you are installing at):

    $ sudo zypper addrepo \
        http://download.opensuse.org/repositories/YaST:/Head/openSUSE_12.3/ \
        YaST:Head
        
Then you can install the module:

    $ sudo zypper install -r YaST:Head:ruby yast2-nfs server

Running
-------

To tun the module, use the following command:

    $ /sbin/yast2 nfs-server

This will run the module in your desktop environment (if you have one running)
of in text mode. For more options, see section on [running modules](TODO) in the
YaST documentation.

Documentation
-------------

User-level documentation for this module is [available at TODO](TODO). See also
[general YaST documentation](http://en.opensuse.org/Portal:YaST).

Development
-----------

This module is developed as part of YaST. See general [YaST development
documentation](TODO) for information how to [get the source code](TODO), [build
it](TODO) and [test it](TODO). You can also learn about [YaST
architecture](TODO) and our [contribution guidelines](TODO).

If you have any question, feel free to ask at the [development mailing
list](http://lists.opensuse.org/yast-devel/) or at the
[#yast](irc://irc.freenode.org/yast) IRC channel on freenode. We'll do our best
to provide timely and accurate answer.
