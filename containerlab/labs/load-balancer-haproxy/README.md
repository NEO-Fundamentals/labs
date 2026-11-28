# Lab: A load balancer: virtual server, pool, health monitor and SNAT

**Folder:** `labs/load-balancer-haproxy/`  **Lab file:** `load-balancer-haproxy.clab.yml`  **Lesson:** NEO-22 F5 BIG-IP: virtual servers, pools, and SNAT  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the load balancer `lb` runs **HAProxy** (in the NEO helper image `neo-tools`), a free, open-source load balancer, in front of three small web servers. The virtual server, the pool, round robin, the health monitor, the address translation on the server side, ratio (weight), disabling a member and cookie persistence are all real HAProxy features doing real work. **It is not an F5 BIG-IP** and there is no F5 software here: `configs/haproxy.cfg` uses BIG-IP names (`vs_web`, `pool_web`), and `configs/bigip-reference.txt` shows the same setup in BIG-IP `tmsh` syntax, as text to compare.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: five Linux containers and one small switch container, under 80 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/load-balancer-haproxy/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0` and `ghcr.io/srl-labs/network-multitool:v0.10.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds; the health monitor marks the members up within about 5 seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
                                    lb (HAProxy)                          web-1  10.22.2.11 :80
   client  ---- eth1 10.22.1.1   virtual server       10.22.2.1 eth2 ---- sw ---- web-2  10.22.2.12 :80
 10.22.1.10          VIP 10.22.1.100 :80 and :8080     (self IP)       (bridge)   web-3  10.22.2.13 :80
                     stats page 10.22.1.1:8404
     client side 10.22.1.0/24                              server side 10.22.2.0/24
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| lb | HAProxy. eth1 = client side, 10.22.1.1/24 and the **virtual server address (VIP) 10.22.1.100**; eth2 = server side, **10.22.2.1/24** (BIG-IP: the self IP). Not a router (forwarding off). Loads `configs/haproxy.cfg`; log `/var/log/haproxy.log` | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| client | 10.22.1.10/24; it reaches only the client side | same | Attach Shell |
| sw | plain Linux bridge for the server side (no filtering) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| web-1, web-2, web-3 | pool members 10.22.2.11, .12, .13, port 80, running `scripts/web_echo.py`: a page that says which server answered, where the connection came from and the `X-Forwarded-For` header; `/health` answers `ok`; log `/var/log/web.log`. **No route to the client side** | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**The setup** (`configs/haproxy.cfg`), BIG-IP idea by BIG-IP idea:

| BIG-IP idea | BIG-IP (text only, `configs/bigip-reference.txt`) | Here (HAProxy) |
|---|---|---|
| Virtual server | `ltm virtual vs_web destination 10.22.1.100:80` | `frontend vs_web` with `bind 10.22.1.100:80` |
| Pool, members | `ltm pool pool_web members add { 10.22.2.11:80 ... }` | `backend pool_web`, `server web-1 10.22.2.11:80` ... |
| Load-balancing method | `load-balancing-mode round-robin` | `balance roundrobin` |
| Health monitor | `ltm monitor http` (send `GET /health`, interval 2) | `option httpchk GET /health`, `check inter 2s fall 3 rise 2` |
| SNAT automap (self IP) | `source-address-translation { type automap }` | built in: lb always opens its own connection to the member, from 10.22.2.1 |
| X-Forwarded-For | HTTP profile `insert-xforwarded-for enabled` | `option forwardfor` |
| Ratio, disable a member | `ratio 3`, `session user-disabled` | `weight 3`, `disable server` (runtime commands) |
| Cookie persistence | persistence profile `cookie`, method insert | `cookie NEO_LB insert` in `pool_app` (virtual server `vs_app`, port 8080) |
| Pool status | `show ltm pool pool_web members` | the statistics page `http://10.22.1.1:8404/stats` (here as CSV) |

## Files

- `load-balancer-haproxy.clab.yml` - the lab drawing. Addresses, the switch, HAProxy and the web servers are set by each node's `exec` lines.
- `configs/haproxy.cfg` - the HAProxy setup (above). `configs/bigip-reference.txt` - the same in BIG-IP `tmsh` commands. **Text only**: nothing loads it.
- `scripts/web_echo.py` - the members' web server (mounted on web-1 to web-3 as `/neo/scripts/`). `scripts/hapctl.py` - sends one command to HAProxy's runtime interface (used on lb in exercise 4).
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, stops web-2's server for a while and starts it again, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `load-balancer-haproxy.drawio` and `load-balancer-haproxy.png` - the prepared diagram.
- `captures/` - three sample captures: `lb-1-full-proxy.pcapng`, `lb-2-member-down.pcapng`, `lb-3-persistence.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `load-balancer-haproxy` > right-click `load-balancer-haproxy.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-load-balancer-haproxy-client curl -s -m 3 http://10.22.1.100/
  ```
  It prints `served by web-1; connection from 10.22.2.1; X-Forwarded-For: 10.22.1.10` (or web-2, web-3): the client reached a pool member through the virtual server. If it prints nothing or a `503` page, wait 5 seconds (the health monitor is still marking the members up) and try again.
- **Reset to the lesson start** (all members up, weights 1, nothing disabled):
  ```
  cd ~/labs-main/containerlab/labs/load-balancer-haproxy
  ```
  ```
  containerlab redeploy -c -t load-balancer-haproxy.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | BIG-IP (text only) | Here |
|---|---|---|
| Are the members up? | `show ltm pool pool_web members` | `docker exec clab-load-balancer-haproxy-client curl -s 'http://10.22.1.1:8404/stats;csv' \| cut -d, -f1,2,18,19 \| grep pool_web` (name, status, weight) |
| Which member got each request? | the virtual server's statistics, a log profile | `docker exec clab-load-balancer-haproxy-lb tail -n 6 /var/log/haproxy.log` |
| What did a member see? | (on the server) | `docker exec clab-load-balancer-haproxy-web-1 cat /var/log/web.log` |
| Change a member at run time | `modify ltm pool ...` | `docker exec clab-load-balancer-haproxy-lb python3 /neo/scripts/hapctl.py <command>` |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/load-balancer-haproxy`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. The virtual server and its pool: round robin.**
```
docker exec clab-load-balancer-haproxy-client sh -c 'for i in 1 2 3 4 5 6; do curl -s -m 3 http://10.22.1.100/; done'
```
```
docker exec clab-load-balancer-haproxy-client curl -s 'http://10.22.1.1:8404/stats;csv' | cut -d, -f1,2,18,19 | grep pool_web
```
```
docker exec clab-load-balancer-haproxy-lb tail -n 6 /var/log/haproxy.log
```
The six answers go **web-1, web-2, web-3, web-1, web-2, web-3** (the starting member can differ): one address, three servers, taken in turn. The statistics list `pool_web,web-1,UP,1` and the same for web-2 and web-3 (status `UP`, weight 1), then `pool_web,BACKEND,UP`. Each log line names the client, the virtual server and the member that served it: `10.22.1.10:... vs_web pool_web/web-2 ... 200 ... "GET / HTTP/1.1"`.

**2. A full proxy: two connections, and SNAT.**
```
docker exec clab-load-balancer-haproxy-web-1 cat /var/log/web.log
```
```
docker exec clab-load-balancer-haproxy-web-1 ip route
```
```
docker exec clab-load-balancer-haproxy-client curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.22.2.11/
```
web-1's log shows every request **from 10.22.2.1**, lb's own server-side address, never from the client's 10.22.1.10; the client's address only travels in the `X-Forwarded-For` header. lb ends the client's TCP connection on the VIP and opens a **second** connection to the member: a full proxy. The member answers 10.22.2.1, which is on its own subnet, so the answer comes back through lb even though web-1 has **no route** to 10.22.1.0/24 (its table shows only 10.22.2.0/24 and the management network). That is what BIG-IP's **SNAT automap** is for: without it the member would answer the client's own address and the reply would miss the load balancer. And the client cannot reach a member directly (`http 000`): only the virtual server is offered. (Sample `lb-1-full-proxy.pcapng`, recorded on both lb ports: with display filter `http.request.uri == "/" or http contains "served by"` you see each request twice, client to 10.22.1.100 and 10.22.2.1 to a member, and each answer twice. The other frames are the health checks of exercise 3.)

**3. The health monitor: a member goes down.** Stop web-2's web server, and at once send six requests (each shows its result and time):
```
docker exec clab-load-balancer-haproxy-web-2 pkill -f web_echo.py
```
```
docker exec clab-load-balancer-haproxy-client sh -c 'for i in 1 2 3 4 5 6; do curl -s -m 10 -o /dev/null -w "http %{http_code} in %{time_total} s\n" http://10.22.1.100/; done'
```
```
docker exec clab-load-balancer-haproxy-client curl -s 'http://10.22.1.1:8404/stats;csv' | cut -d, -f1,2,18,19 | grep pool_web
```
```
docker exec clab-load-balancer-haproxy-lb grep 'is DOWN' /var/log/haproxy.log
```
One or two requests get **`http 503 in 3.0 s`**, the others `http 200` at once. The monitor checks every 2 seconds and needs **three** failures in a row, so for about 6 seconds lb still believes in web-2: a request sent to web-2 in that window is refused, lb tries again three times, one second apart, and then answers `503 Service Unavailable` (in the log: `pool_web/web-2 ... 503 ... SC--`). After that, the statistics show `pool_web,web-2,DOWN` and the log `Server pool_web/web-2 is DOWN, reason: Layer4 connection problem, info: "Connection refused"`, and every request goes to web-1 or web-3. A monitor never makes a failure invisible: it shortens it. (Sample `lb-2-member-down.pcapng`, server side: the checks to 10.22.2.12 answered with `[RST, ACK]`, and lb's retries.) Start web-2 again and check after 5 seconds: it is `UP` again after two good checks (`rise 2`).
```
docker exec -d clab-load-balancer-haproxy-web-2 sh -c 'python3 -u /neo/scripts/web_echo.py web-2 >>/var/log/web.log 2>&1'
```
```
docker exec clab-load-balancer-haproxy-client curl -s 'http://10.22.1.1:8404/stats;csv' | cut -d, -f1,2,18,19 | grep pool_web
```

**4. Ratio and disabling a member, at run time.** BIG-IP: `ratio 3` on a member (with the ratio method), and **Disabled** for maintenance. Give web-1 three times the share, and count ten answers:
```
docker exec clab-load-balancer-haproxy-lb python3 /neo/scripts/hapctl.py set server pool_web/web-1 weight 3
```
```
docker exec clab-load-balancer-haproxy-client sh -c 'for i in $(seq 10); do curl -s -m 3 http://10.22.1.100/ | cut -d";" -f1; done | sort | uniq -c'
```
About `6 served by web-1`, `2 served by web-2`, `2 served by web-3`. Now put web-1 back to 1 and take web-3 out for maintenance:
```
docker exec clab-load-balancer-haproxy-lb python3 /neo/scripts/hapctl.py set server pool_web/web-1 weight 1
```
```
docker exec clab-load-balancer-haproxy-lb python3 /neo/scripts/hapctl.py disable server pool_web/web-3
```
```
docker exec clab-load-balancer-haproxy-client sh -c 'for i in $(seq 6); do curl -s -m 3 http://10.22.1.100/ | cut -d";" -f1; done | sort | uniq -c'
```
```
docker exec clab-load-balancer-haproxy-client curl -s 'http://10.22.1.1:8404/stats;csv' | cut -d, -f1,2,18,19 | grep pool_web
```
Three each for web-1 and web-2, none for web-3, whose status is now **`MAINT`** (maintenance): taken out by an operator, not by the monitor. Unlike exercise 3, no request failed: lb stops sending new requests to it first. Put it back:
```
docker exec clab-load-balancer-haproxy-lb python3 /neo/scripts/hapctl.py enable server pool_web/web-3
```
Each `hapctl.py` command prints `(done)`. These run-time changes are not saved in `haproxy.cfg`; a reset (or a restart of HAProxy) forgets them.

**5. Cookie persistence: the second virtual server.** `vs_app` on port 8080 uses the same three servers, with **cookie persistence**: lb adds a cookie that names the member, and the browser's next requests go back to it. Without a cookie, each request goes to the next member:
```
docker exec clab-load-balancer-haproxy-client sh -c 'for i in 1 2 3; do curl -s -m 3 http://10.22.1.100:8080/ | cut -d";" -f1; done'
```
Now like a browser, keeping the cookie (`-c` saves it, `-b` sends it back):
```
docker exec clab-load-balancer-haproxy-client sh -c 'curl -s -m 3 -c /tmp/jar -D - -o /dev/null http://10.22.1.100:8080/ | grep -i set-cookie; for i in 1 2 3; do curl -s -m 3 -b /tmp/jar http://10.22.1.100:8080/ | cut -d";" -f1; done'
```
The first list rotates; the second starts with `set-cookie: NEO_LB=w1; path=/` (or `w2`, `w3`) and then names the **same** member three times. Persistence keeps a user on one server (useful when a server keeps the user's session in memory), at the price of an uneven spread. (Sample `lb-3-persistence.pcapng`, client side: the `Set-Cookie` in the first answer and the `Cookie: NEO_LB=...` header in the next three requests.)

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open. The server side always carries the health checks too (each member is checked every 2 seconds by each of the two pools); the display filter `http.request.uri != "/health"` hides most of them.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `lb-1-full-proxy.pcapng` | lb:eth1 and lb:eth2 | 321 | six requests: each one twice, client 10.22.1.10 to the VIP 10.22.1.100, then 10.22.2.1 to a member (each member twice) with `X-Forwarded-For: 10.22.1.10`; and the health checks |
| `lb-2-member-down.pcapng` | lb:eth2 (server side) | 325 | web-2's server stops: from then on every connection to 10.22.2.12 port 80 is answered with `[RST, ACK]` (checks and lb's retries); the other members keep serving |
| `lb-3-persistence.pcapng` | lb:eth1 (client side) | 37 | four requests to 10.22.1.100:8080: the first answer sets `NEO_LB=w...` (the member it picked), the next three requests send it back |

## What this lab does not do

- **No F5 BIG-IP.** The `tmsh` commands are text to compare; BIG-IP's GUI, iRules, SSL offload profiles, partitions, high availability and its monitors' exact timing are not here.
- HTTP only (no HTTPS on the virtual server), IPv4 only, one load balancer (no pair).
- The statistics page is read as CSV from the client; there is no browser in the lab network.
- A veth pair carries each link; there is no real cable.

Not affiliated with or endorsed by F5, Inc. or HAProxy Technologies. F5 and BIG-IP are trademarks of F5, Inc. HAProxy is a trademark of HAProxy Technologies. The BIG-IP commands in this folder are text to compare; this lab does not run F5 software.

## Troubleshooting

1. **The check in Start prints a `503` page or nothing.** The health monitor marks the members up about 4 seconds after the deploy: wait and try again. `docker exec clab-load-balancer-haproxy-lb tail /var/log/haproxy.log` should show no `ALERT` line.
2. **Exercise 3 had no `503` at all.** No request happened to reach web-2 in the 6 seconds before it was marked down (it depends on where the round robin stood). Start web-2 again, wait 5 seconds, and repeat: the two commands must follow quickly.
3. **web-2 stays `DOWN` after you started it again.** Check that its server runs: `docker exec clab-load-balancer-haproxy-web-2 pgrep -f web_echo.py` prints a number; if not, run the start command again.
4. **`hapctl.py` says `No such file or directory`.** HAProxy is not running on lb: reset the lab.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/load-balancer-haproxy
```
```
containerlab destroy --cleanup -t load-balancer-haproxy.clab.yml
```
`--cleanup` also removes the generated `clab-load-balancer-haproxy` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-load-balancer-haproxy` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/load-balancer-haproxy/clab-load-balancer-haproxy
```
Your capture files in your Home folder are not touched.

