echo 1024 65000 > /proc/sys/net/ipv4/ip_local_port_range
echo "port range"
sysctl -w net.ipv4.tcp_tw_reuse=1
echo "reuse socket"

