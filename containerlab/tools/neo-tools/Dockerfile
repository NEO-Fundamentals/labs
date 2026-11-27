# neo-tools: the one small helper image the NEO labs use where SR Linux and FRR cannot play the role
# (stateful firewall, load balancer, DHCP/DNS server, SSH host, VRRP pair, IPsec endpoint).
# Built only from public Debian packages. Nothing in it is licensed or account-gated.
#   Build:   docker build -t ghcr.io/neo-fundamentals/neo-tools:1.0.0 .
#   Smoke:   ./smoke-test.sh ghcr.io/neo-fundamentals/neo-tools:1.0.0
FROM debian:12-slim

LABEL org.opencontainers.image.title="neo-tools" \
      org.opencontainers.image.description="Linux helper container for NEO Containerlab labs" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl iproute2 iputils-ping iputils-tracepath traceroute net-tools ethtool bridge-utils procps \
      tcpdump nftables conntrack iperf3 netcat-openbsd bind9-dnsutils \
      dnsmasq isc-dhcp-client openssh-server openssh-client \
      haproxy keepalived snmp snmpd python3 \
      strongswan-swanctl charon-systemd \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd /srv/www

# ssh host keys are made when each container starts, so no two lab containers share a key
COPY neo-init.sh /usr/local/bin/neo-init
RUN chmod 0755 /usr/local/bin/neo-init
ENTRYPOINT ["/usr/local/bin/neo-init"]
CMD ["sleep", "infinity"]
