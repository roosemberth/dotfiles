blacklist /
read-only /bin
read-only /sbin
read-only /lib
read-only /lib64

read-only /usr/bin
read-only /usr/etc
read-only /usr/lib
read-only /usr/sbin

#read-only /home

caps.drop all
hostname tokamak
machine-id
netfilter
noroot
nonewprivs

overlay
private
private-dev
private-etc
private-opt
private-srv
private-tmp
