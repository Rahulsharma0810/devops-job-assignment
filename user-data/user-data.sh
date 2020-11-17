#!/bin/bash
#Let the script wait for 5seconds
sleep 5s
#Accept Agreement
echo "yes"
#Primary server node
echo "yes"
#Network interface
echo ""
#Port number for admin web UI
echo ""
#Port number for OpenVPN Daemon
echo ""
#Route client traffic through VPN
echo "yes"
#Route DNS traffic though VPN
echo "yes"
#Auth via local db
echo ""
#Pvt subnets accessible by clients
echo ""
#Login to admin as "openvpn" user
echo ""
#Licence key
echo ""
#Setting password for user openvpn
# This should not be in git, always use vault to keep secrets.
echo "openvpn:admin_34fqerq83t" | chpasswd

# Disable TLS Auth
/usr/local/openvpn_as/scripts/sacli --key "vpn.server.tls_auth" --value="false" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_dns" --value="true" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_gw" --value="true" ConfigPut
/usr/local/openvpn_as/scripts/sacli start