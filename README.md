YaST NFS Server Module
======================

The YaST NFS Server module manages configuration of an
[NFS](http://en.wikipedia.org/wiki/Network_File_System) server. It's a part of
[YaST](https://en.opensuse.org/Portal:YaST) — installation and configuration
tool for [openSUSE](http://www.opensuse.org/) and [SUSE Linux
Enterprise](https://www.suse.com/products/server/) (SLE).

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

    $ sudo zypper install yast2-nfs-server

Running
-------

To run the module, use the following command:

    $ sudo /sbin/yast2 nfs-server

This will run the module in text mode. For more options, including running in
your desktop environment, see section on [running modules](TODO) in the YaST
documentation.

Documentation
-------------

User-level documentation for this module is [available at TODO](TODO). See also
[general YaST documentation](http://en.opensuse.org/Portal:YaST).

Development
-----------

This module is developed as part of YaST. See [YaST development
documentation](TODO) for information about [YaST architecture](TODO),
[development environment](TODO) and other development-related topics.

To get the source code, clone the GitHub repository:

    $ git clone https://github.com/yast/yast-nfs-server.git

To run the module from the source code, use the `run` Rake task:

    $ rake run[nfs-server]

To run the testsuite, use the `test` Rake task:

    $ rake test

Before submitting any change please read our [contribution
guidelines](CONTRIBUTING.md).

If you have any question, feel free to ask at the [development mailing
list](http://lists.opensuse.org/yast-devel/) or at the #yast IRC channel on
freenode. We'll do our best to provide a timely and accurate answer.
