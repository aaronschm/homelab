# 2026-08-02 01:44:02 by RouterOS 7.23.2
# software id = CMX9-H8AJ
#
# model = CRS309-1G-8S+
# serial number = HH20ABZVVJE
/interface bridge
add name=bridge1 pvid=20 vlan-filtering=yes
/interface wireguard
add listen-port=13231 mtu=1420 name=wg-vpn
/interface vlan
add comment=WAN-Telekom interface=sfp-sfpplus7 name=WAN-Telekom vlan-id=7
add interface=bridge1 name=vlan-cloud vlan-id=80
add interface=bridge1 name=vlan-cluster vlan-id=25
add interface=bridge1 name=vlan-dmz vlan-id=24
add interface=bridge1 name=vlan-guest vlan-id=90
add interface=bridge1 name=vlan-iot vlan-id=30
add interface=bridge1 name=vlan-mgmt vlan-id=1
add interface=bridge1 name=vlan-server vlan-id=20
add interface=bridge1 name=vlan-trusted vlan-id=10
/interface pppoe-client
add add-default-route=yes disabled=no interface=WAN-Telekom name=\
    "PPPoE Telekom" user=551141053233
/ip pool
add name=dhcp_pool_1 ranges=10.10.1.10-10.10.1.254
add name=dhcp_pool_10 ranges=10.10.10.10-10.10.10.254
add name=dhcp_pool_20 ranges=10.10.20.10-10.10.20.254
add name=dhcp_pool_24 ranges=10.10.24.10-10.10.24.254
add name=dhcp_pool_25 ranges=10.10.25.10-10.10.25.254
add name=dhcp_pool_30 ranges=10.10.30.10-10.10.30.254
add name=dhcp_pool_80 ranges=10.10.80.10-10.10.80.254
add name=dhcp_pool_90 ranges=10.10.90.10-10.10.90.254
/ip dhcp-server
add address-pool=dhcp_pool_1 interface=vlan-mgmt name=dhcp-mgmt
add address-pool=dhcp_pool_10 interface=vlan-trusted name=dhcp-trusted
add address-pool=dhcp_pool_20 interface=vlan-server name=dhcp-server
add address-pool=dhcp_pool_24 interface=vlan-dmz name=dhcp-dmz
add address-pool=dhcp_pool_25 interface=vlan-cluster name=dhcp-cluster
add address-pool=dhcp_pool_30 interface=vlan-iot name=dhcp-iot
add address-pool=dhcp_pool_80 interface=vlan-cloud name=dhcp-cloud
add address-pool=dhcp_pool_90 interface=vlan-guest name=dhcp-guest
/interface bridge port
add bridge=bridge1 comment=UDM interface=sfp-sfpplus1
add bridge=bridge1 comment=PVE interface=sfp-sfpplus2 pvid=20
add bridge=bridge1 comment=Laconia interface=sfp-sfpplus3 pvid=10
add bridge=bridge1 comment="RJ45 Forwarding" interface=ether1
add bridge=bridge1 comment="link - CRS310" interface=sfp-sfpplus8
/interface bridge vlan
add bridge=bridge1 comment=Trusted tagged=sfp-sfpplus1,sfp-sfpplus8 untagged=\
    sfp-sfpplus3,ether1 vlan-ids=10
add bridge=bridge1 comment=Server tagged=sfp-sfpplus1,sfp-sfpplus8,ether1 \
    untagged=sfp-sfpplus2,bridge1 vlan-ids=20
add bridge=bridge1 comment=DMZ tagged=sfp-sfpplus1,sfp-sfpplus2,ether1 \
    vlan-ids=24
add bridge=bridge1 comment=Cluster tagged=sfp-sfpplus1,sfp-sfpplus2,ether1 \
    vlan-ids=25
add bridge=bridge1 comment=Cloud tagged=sfp-sfpplus1,sfp-sfpplus2 vlan-ids=80
add bridge=bridge1 comment=MGMT tagged=sfp-sfpplus3 untagged=\
    sfp-sfpplus1,sfp-sfpplus8 vlan-ids=1
add bridge=bridge1 comment=Guest tagged=sfp-sfpplus1,sfp-sfpplus8,ether1 \
    vlan-ids=90
add bridge=bridge1 comment=IoT tagged=sfp-sfpplus1,sfp-sfpplus8,ether1 \
    vlan-ids=30
/interface wireguard peers
add allowed-address=10.10.100.2/32 client-address=10.10.100.2/24 \
    client-allowed-address=0.0.0.0/0 client-dns=10.10.20.99 client-endpoint=\
    home.aaronschmidt.de client-keepalive=21s client-listen-port=13231 \
    interface=wg-vpn name=Iphone17 public-key=\
    "zlKYPIW4Uf3rWWtbO+qe3s48aXSOxiDepOW5qkSRAVM="
add allowed-address=10.10.100.3/32 client-address=10.10.100.3/24 \
    client-allowed-address=0.0.0.0/0 client-dns=10.10.20.99 client-endpoint=\
    home.aaronschmidt.de client-keepalive=21s client-listen-port=13231 \
    interface=wg-vpn name=IpadProM2 public-key=\
    "kApL2/fglOK6FSMFh8v0Z+e2HYPsphrEgKKi1PVvwkU="
add allowed-address=10.10.100.4/32 client-address=10.10.100.4/24 \
    client-allowed-address=0.0.0.0/0 client-dns=10.10.20.99 client-endpoint=\
    home.aaronschmidt.de client-keepalive=21s client-listen-port=13231 \
    interface=wg-vpn name=Laptop_Aaron public-key=\
    "Q2frnPR9J4KBrweyqJeMRXC/BheEccpECf/be3OSHFM="
add allowed-address=10.10.100.5/32 client-address=10.10.100.5/24 \
    client-allowed-address=0.0.0.0/0 client-dns=10.10.20.99 client-endpoint=\
    home.aaronschmidt.de client-keepalive=21s client-listen-port=13231 \
    interface=wg-vpn name=Papa public-key=\
    "VU4MJ0ploX4GyFMxNDJSFvpn57Zdv1rFt86pN7WCOw8="
add allowed-address=10.10.100.6/32 client-address=10.10.100.6/24 \
    client-allowed-address=0.0.0.0/0 client-dns=10.10.20.99 client-endpoint=\
    home.aaronschmidt.de client-keepalive=21s client-listen-port=13231 \
    interface=wg-vpn name=Mama public-key=\
    "zwCavoNWr2IGDbFhvHITjCckUm+0OWtT6k6iYDc2ySE="
add allowed-address=10.10.100.7/32 client-address=10.10.100.7/24 \
    client-allowed-address=0.0.0.0/0 client-dns=10.10.20.99 client-endpoint=\
    home.aaronschmidt.de client-keepalive=21s client-listen-port=13231 \
    interface=wg-vpn name=Indra public-key=\
    "RZAjAHKJdrSiKnpUKmQXw6DCiITtbneLaGS1FQj7mHI="
/ip address
add address=10.10.1.2/24 comment=Management interface=vlan-mgmt network=\
    10.10.1.0
add address=10.10.10.1/24 comment=Trusted interface=vlan-trusted network=\
    10.10.10.0
add address=10.10.20.1/24 comment=Server interface=vlan-server network=\
    10.10.20.0
add address=10.10.24.1/24 comment=DMZ interface=vlan-dmz network=10.10.24.0
add address=10.10.25.1/24 comment=Cluster interface=vlan-cluster network=\
    10.10.25.0
add address=10.10.30.1/24 comment=IoT interface=vlan-iot network=10.10.30.0
add address=10.10.80.1/24 comment=Cloud interface=vlan-cloud network=\
    10.10.80.0
add address=10.10.90.1/24 comment=Guest interface=vlan-guest network=\
    10.10.90.0
add address=10.10.100.1/24 interface=wg-vpn network=10.10.100.0
/ip dhcp-server lease
add address=10.10.10.251 client-id=1:d4:5d:64:d8:4:43 mac-address=\
    D4:5D:64:D8:04:43 server=dhcp-trusted
/ip dhcp-server network
add address=10.10.1.0/24 comment=Management dns-server=\
    10.10.20.99,1.1.1.1,8.8.8.8 gateway=10.10.1.2
add address=10.10.10.0/24 comment=Trusted dns-server=\
    10.10.20.99,1.1.1.1,8.8.8.8 gateway=10.10.10.1
add address=10.10.20.0/24 comment=Server dns-server=\
    10.10.20.99,1.1.1.1,8.8.8.8 gateway=10.10.20.1
add address=10.10.24.0/24 comment=DMZ dns-server=10.10.20.99,1.1.1.1,8.8.8.8 \
    gateway=10.10.24.1
add address=10.10.25.0/24 comment=Cluster dns-server=\
    10.10.20.99,1.1.1.1,8.8.8.8 gateway=10.10.25.1
add address=10.10.30.0/24 comment=IoT dns-server=10.10.20.99,1.1.1.1,8.8.8.8 \
    gateway=10.10.30.1
add address=10.10.80.0/24 comment=Cloud dns-server=\
    10.10.20.99,1.1.1.1,8.8.8.8 gateway=10.10.80.1
add address=10.10.90.0/24 comment=Guest dns-server=\
    10.10.20.99,1.1.1.1,8.8.8.8 gateway=10.10.90.1
/ip dns
set servers=10.10.1.1
/ip firewall filter
add action=fasttrack-connection chain=forward comment="FastTrack Rule" \
    connection-state=established,related
add action=accept chain=forward comment="Accept Forward Established/Related" \
    connection-state=established,related
add action=accept chain=input comment="Accept Established/Related" \
    connection-state=established,related,untracked
add action=accept chain=forward comment="Allow ICMP (Ping/PMTUD)" disabled=\
    yes protocol=icmp
add action=drop chain=input comment="Drop Invalid" connection-state=invalid
add action=accept chain=input comment="Allow Ping (ICMP)" disabled=yes \
    protocol=icmp
add action=accept chain=input comment="Allow Local DHCP Requests" dst-port=67 \
    protocol=udp
add action=accept chain=input comment="Allow WinBox/SSH from Mgmt (vlan1)" \
    in-interface=vlan-mgmt
add action=accept chain=input comment=\
    "Allow WinBox/SSH from Trusted (vlan10)" in-interface=vlan-trusted
add action=accept chain=input comment="Allow WireGuard VPN Server" dst-port=\
    13231 in-interface="PPPoE Telekom" protocol=udp
add action=accept chain=forward comment=\
    "WireGuard Master Key (Acts like vlan10)" in-interface=wg-vpn
add action=drop chain=input comment=\
    "DEFAULT DROP - Input (Block all other access to router)"
add action=accept chain=forward comment="Accept Established/Related" \
    connection-state=established,related,untracked
add action=accept chain=forward comment="Accept Port Forwarding (Traefik)" \
    connection-nat-state=dstnat
add action=drop chain=forward comment="Drop Invalid" connection-state=invalid
add action=accept chain=forward comment="Mgmt (vlan1) to ANY" in-interface=\
    vlan-mgmt
add action=accept chain=forward comment="Trusted (vlan10) to ANY" \
    in-interface=vlan-trusted
add action=accept chain=forward comment="Server to WAN" in-interface=\
    vlan-server out-interface="PPPoE Telekom"
add action=accept chain=forward comment="DMZ to WAN" in-interface=vlan-dmz \
    out-interface="PPPoE Telekom"
add action=accept chain=forward comment="Guest to WAN" in-interface=\
    vlan-guest out-interface="PPPoE Telekom"
add action=accept chain=forward comment="IoT to WAN" in-interface=vlan-iot \
    out-interface="PPPoE Telekom"
add action=accept chain=forward comment="Server to Cluster" in-interface=\
    vlan-server out-interface=vlan-cluster
add action=accept chain=forward comment="Server to DMZ" in-interface=\
    vlan-server out-interface=vlan-dmz
add action=accept chain=forward comment="Server to IoT" in-interface=\
    vlan-server out-interface=vlan-iot
add action=accept chain=forward comment="IoT to Server" in-interface=vlan-iot \
    out-interface=vlan-server
add action=accept chain=forward comment="Cluster to DMZ" in-interface=\
    vlan-cluster out-interface=vlan-dmz
add action=accept chain=forward comment="Cluster to Server" in-interface=\
    vlan-cluster out-interface=vlan-server
add action=accept chain=forward comment="DMZ to Cluster Ports" dst-port=\
    80,443,8080,50000 in-interface=vlan-dmz out-interface=vlan-cluster \
    protocol=tcp
add action=accept chain=forward comment="DMZ to Server Ports" dst-port=\
    80,443,8080 in-interface=vlan-dmz out-interface=vlan-server protocol=tcp
add action=accept chain=forward comment="DMZ DNS to Adguard" dst-port=53 \
    in-interface=vlan-dmz out-interface=vlan-server protocol=udp
add action=drop chain=forward comment=\
    "DEFAULT DROP - Forward (Isolates everything else)"
/ip firewall mangle
add action=change-mss chain=forward comment="Fix PPPoE MTU/MSS" new-mss=\
    clamp-to-pmtu protocol=tcp tcp-flags=syn
/ip firewall nat
add action=masquerade chain=srcnat out-interface="PPPoE Telekom"
add action=dst-nat chain=dstnat dst-port=443 in-interface="PPPoE Telekom" \
    protocol=tcp to-addresses=10.10.20.50 to-ports=443
add action=dst-nat chain=dstnat dst-port=80 in-interface="PPPoE Telekom" \
    protocol=tcp to-addresses=10.10.20.50 to-ports=80
add action=masquerade chain=srcnat dst-address=10.10.20.50 dst-port=80,443 \
    protocol=tcp src-address=10.10.20.0/24
/ip route
add disabled=no dst-address=0.0.0.0/0 gateway=10.10.1.1 routing-table=main \
    suppress-hw-offload=no
/ip service
set ssh address=10.10.1.0/24,10.10.10.0/24
set www address=10.10.1.0/24,10.10.10.0/24
set winbox address=10.10.1.0/24,10.10.10.0/24
/system clock
set time-zone-name=Europe/Berlin
/system routerboard settings
set enter-setup-on=delete-key
/system swos
set address-acquisition-mode=static static-ip-address=10.10.1.2
