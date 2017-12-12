centos-bootstrap
==============

Bootstrap a base Centos Linux system from any GNU distro.

Install
=======
    # install -m 755 rpm2cpio /usr/local/bin/rpm2cpio
    # install -m 755 rpmextract.sh /usr/local/bin/rpmextract.sh
    # install -m 755 centos-bootstrap.sh /usr/local/bin/centos-bootstrap

Examples
=========

Create a base centos distribution in directory 'dest':

    # centos-bootstrap dest
   
The same but use arch aarch64 and a given repository source:

    # centos-bootstrap -a aarch64 -r "http://mirrors.tuna.tsinghua.edu.cn/centos-altarch" dest 

Usage
=====

Once the process has finished, chroot to the destination directory (default user: root/root):

    # chroot destination

Note that some packages require some system directories to be mounted. Some of the commands you can try:

    # mount --bind /proc dest/proc
    # mount --bind /sys dest/sys
    # mount --bind /dev dest/dev
    # mount --bind /dev/pts dest/dev/pts
    
License
=======
This project is fork from https://github.com/tokland/arch-bootstrap
This project is licensed under the terms of the MIT license
