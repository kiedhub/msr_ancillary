#!/usr/bin/env ash

# docker container customization

# setup loopback interface
#ip link add name lo10 type dummy
#ip addr add 10.255.255.1/32 dev lo10

# configure configuration
mv /etc/raddb/mods-config/files/authorize /tmp/authorize.orig
mv /etc/raddb/clients.conf /tmp/clients.conf.orig

ln -s /usr/local/etc/radius/authorize /etc/raddb/mods-config/files/authorize
ln -s /usr/local/etc/radius/clients.conf /etc/raddb/clients.conf

chown root:radius /etc/raddb/mods-config/files/authorize
chmod 644 /etc/raddb/mods-config/files/authorize

chown root:radius /etc/raddb/clients.conf
chmod 644 /etc/raddb/clients.conf

chown -R radius:radius /var/log/radius
chmod -R 750 /var/log/radius

radiusd

