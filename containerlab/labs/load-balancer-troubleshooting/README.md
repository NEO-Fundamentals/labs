# Lab: Load balancer troubleshooting: the virtual server is up, the application is down

**Folder:** `labs/load-balancer-troubleshooting/`  **Lab file:** `load-balancer-troubleshooting.clab.yml`  **Lesson:** NEO-23 F5 troubleshooting: when the VIP is up and the application is down  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the load balancer of NEO-22 again: `lb` runs **HAProxy** (in the NEO helper image `neo-tools`), a free, open-source load balancer, in front of three small web servers. Here you break it on purpose, three different ways, and find each fault from the outside in: the client's answer, the pool status, the load balancer's log, then the member itself. The health monitor, the pool status, the log and the configuration check are real HAProxy features doing real work. **It is not an F5 BIG-IP** and there is no F5 software here: `configs/bigip-reference.txt` lists the BIG-IP `tmsh` commands for the same checks, as text to compare.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: five Linux containers and one small switch container, under 80 MB together (measured: about 75 MB). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/load-balancer-troubleshooting/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0` and `ghcr.io/srl-labs/network-multitool:v0.10.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds; the health monitor marks the members up within about 5 seconds. The lab is ready when the check in **Start** passes.
- **Lesson before:** NEO-22 (`load-balancer-haproxy`) explains the virtual server, the pool and the health monitor. This lab uses the same setup on 10.23.x addresses.

## What this lab builds

```
                                    lb (HAProxy)                          web-1  10.23.2.11 :80
   client  ---- eth1 10.23.1.1   virtual server       10.23.2.1 eth2 ---- sw ---- web-2  10.23.2.12 :80
 10.23.1.10          VIP 10.23.1.100 :80              (self IP)       (bridge)   web-3  10.23.2.13 :80
                     stats page 10.23.1.1:8404
     client side 10.23.1.0/24                              server side 10.23.2.0/24
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| lb | HAProxy. eth1 = client side, 10.23.1.1/24 and the **virtual server address (VIP) 10.23.1.100**; eth2 = server side, **10.23.2.1/24** (the self IP). Not a router. Loads `configs/haproxy.cfg`; log `/var/log/haproxy.log` | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| client | 10.23.1.10/24; it reaches only the client side | same | Attach Shell |
| sw | plain Linux bridge for the server side (no filtering) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| web-1, web-2, web-3 | pool members 10.23.2.11, .12, .13, port 80, running `scripts/web_echo.py`: `/` says which server answered, `/health` answers `ok`, any other page `404`; log `/var/log/web.log` | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**The setup** (`configs/haproxy.cfg`): virtual server `vs_web` on 10.23.1.100:80, pool `pool_web` with the three members, round robin, and a health monitor that asks each member for `GET /health` every 2 seconds and expects `200`; three failed checks in a row mark a member down, two good ones mark it up again.

## Files

- `load-balancer-troubleshooting.clab.yml` - the lab drawing. Addresses, the switch, HAProxy and the web servers are set by each node's `exec` lines.
- `configs/haproxy.cfg` - the HAProxy setup of the lesson start. `configs/bigip-reference.txt` - the BIG-IP `tmsh` commands for the same checks. **Text only**: nothing loads it.
- `changes/haproxy-check-page.cfg` - a better monitor (exercise 3). `changes/haproxy-change.cfg` - the change of exercise 4.
- `scripts/fault.sh` - puts the fault of an exercise in place: `bash scripts/fault.sh 1` (exercise 2), `2` (exercise 3), `3` (exercise 4). Try each exercise before you read how the fault is made.
- `scripts/reload.sh` - loads an HAProxy configuration on lb the careful way: it checks the file first and loads it only if it is valid. `scripts/hapctl.py` - sends one command to HAProxy's runtime interface. `scripts/web_echo.py` - the members' web server.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, puts each fault in place and undoes it, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `load-balancer-troubleshooting.drawio` and `load-balancer-troubleshooting.png` - the prepared diagram.
- `captures/` - three sample captures: `lbts-1-app-down.pcapng`, `lbts-2-broken-member.pcapng`, `lbts-3-wrong-monitor.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `load-balancer-troubleshooting` > right-click `load-balancer-troubleshooting.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-load-balancer-troubleshooting-client curl -s -m 3 http://10.23.1.100/
  ```
  It prints `served by web-1; connection from 10.23.2.1; X-Forwarded-For: 10.23.1.10` (or web-2, web-3). If it prints nothing or a `503` page, wait 5 seconds (the health monitor is still marking the members up) and try again.
- **Reset to the lesson start** (all web servers running normally, HAProxy with `configs/haproxy.cfg`): do this whenever a fault is left over.
  ```
  cd ~/labs-main/containerlab/labs/load-balancer-troubleshooting
  ```
  ```
  containerlab redeploy -c -t load-balancer-troubleshooting.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

A fault is found from the outside in. These are the four places to look, in order:

| Question | BIG-IP (text only) | Here |
|---|---|---|
| 1. What does the user get? | (a browser, or `curl` on a client) | `docker exec clab-load-balancer-troubleshooting-client curl -s -m 10 -w '\nhttp %{http_code} in %{time_total} s\n' http://10.23.1.100/` |
| 2. What does the load balancer think of the pool? | `show ltm pool pool_web members` (Availability, Monitor status) | `docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' \| cut -d, -f1,2,18,37,38,44 \| grep pool_web` |
| 3. What did the load balancer log? | `/var/log/ltm` | `docker exec clab-load-balancer-troubleshooting-lb tail -n 5 /var/log/haproxy.log` |
| 4. What does the member answer when lb asks it directly? | `curl` in the BIG-IP's bash | `docker exec clab-load-balancer-troubleshooting-lb curl -s -m 2 -w '  [http %{http_code}]\n' http://10.23.2.11/health` |

The statistics columns picked by `cut -d, -f1,2,18,37,38,44` are: pool, member, **status** (`UP`, `DOWN`, `MAINT`), the **last health check's result** (`L7OK` = the page answered as expected; `L4CON` = the connection was refused; `L7STS` = the page answered with the wrong status), that check's **HTTP code**, and the number of **5xx answers** the member gave to real requests.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/load-balancer-troubleshooting`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. What healthy looks like.** Before you look for faults, know the good picture:
```
docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' | cut -d, -f1,2,18,37,38,44 | grep pool_web
```
```
docker exec clab-load-balancer-troubleshooting-client sh -c 'for i in 1 2 3; do curl -s -m 3 http://10.23.1.100/; done'
```
Each member shows `UP,L7OK,200,0`: up, its last check got the page it expected with code 200, and no 5xx answers. The last line, `pool_web,BACKEND,UP,,,0`, is the pool as a whole. The three requests are served by web-1, web-2 and web-3 in turn.

**2. The VIP is up, the application is down.** Put the fault in place, then **wait about 10 seconds** (the monitor needs three failed checks, 2 seconds apart):
```
bash scripts/fault.sh 1
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s -m 10 -w '\nhttp %{http_code} in %{time_total} s\n' http://10.23.1.100/
```
```
docker exec clab-load-balancer-troubleshooting-client sh -c 'nc -z -w 2 10.23.1.100 80; echo "nc exit $?"'
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' | cut -d, -f1,2,18,37,38,44 | grep pool_web
```
```
docker exec clab-load-balancer-troubleshooting-lb sh -c "grep 'pool_web/<NOSRV>' /var/log/haproxy.log | tail -n 1; grep '^Server' /var/log/haproxy.log | tail -n 3"
```
```
docker exec clab-load-balancer-troubleshooting-lb curl -s -m 2 -o /dev/null -w 'http %{http_code}\n' http://10.23.2.11/health
```
```
docker exec clab-load-balancer-troubleshooting-web-1 ss -ltn 'sport = :80'
```
The user gets `503 Service Unavailable` ("No server is available to handle this request") **at once**, in about 0.001 s. Yet the virtual server is up: `nc` connects to 10.23.1.100 port 80 (`nc exit 0`), and a ping or a port check from a monitoring system would say all is well. The pool says otherwise: every member is `DOWN,L4CON` (the check's connection was refused) and the pool itself is `DOWN`. The log line for the request names no member (`pool_web/<NOSRV> ... 503 ... SC--`), and the three `Server pool_web/web-N is DOWN, reason: Layer4 connection problem, info: "Connection refused"` lines say why. Asked directly, web-1 refuses lb (`http 000`), and `ss` lists **no** program listening on port 80: the web server is not running. On a BIG-IP the virtual server turns red, "The children pool member(s) are down", for the same reason. (If you were quicker than 10 seconds, the request waited about 3 s and still got a 503: lb tried a member it still believed in, three times.) (Sample `lbts-1-app-down.pcapng`, recorded on both lb ports: the refused checks `[RST, ACK]` on the server side, then three requests that get 503 with no connection to any member.)

Fix it: start the three web servers again, wait 5 seconds and look at the pool:
```
for s in web-1 web-2 web-3; do docker exec -d clab-load-balancer-troubleshooting-$s sh -c "python3 -u /neo/scripts/web_echo.py $s >>/var/log/web.log 2>&1"; done
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' | cut -d, -f1,2,18,37,38,44 | grep pool_web
```
All three are `UP,L7OK,200` again: two good checks were enough.

**3. The monitor says up, but users get errors.**
```
bash scripts/fault.sh 2
```
```
docker exec clab-load-balancer-troubleshooting-client sh -c 'for i in 1 2 3 4 5 6; do curl -s -m 3 -w "  [http %{http_code}]\n" http://10.23.1.100/; done'
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' | cut -d, -f1,2,18,37,38,44 | grep pool_web
```
```
docker exec clab-load-balancer-troubleshooting-lb grep ' 500 ' /var/log/haproxy.log
```
```
docker exec clab-load-balancer-troubleshooting-lb sh -c "curl -s -m 2 -w '  [http %{http_code}]\n' http://10.23.2.13/health; curl -s -m 2 -w '  [http %{http_code}]\n' http://10.23.2.13/"
```
Two of the six requests get `application error on web-3: database unavailable [http 500]`; the others are fine. One user in three sees an error, and the pool says **all is well**: every member `UP,L7OK,200`. Only the last column shows it: web-3 has given `2` answers with a 5xx code, and the log names it (`pool_web/web-3 ... 500`). Asked directly, web-3 answers its health page `ok [http 200]` and its real page `500`. The monitor asks `/health`, which only proves that the web server process runs; the application behind it fails. A monitor tests what it asks, nothing more.

First take web-3 out of service (BIG-IP: disable the member), so users stop getting errors at once:
```
docker exec clab-load-balancer-troubleshooting-lb python3 /neo/scripts/hapctl.py disable server pool_web/web-3
```
```
docker exec clab-load-balancer-troubleshooting-client sh -c 'for i in 1 2 3 4; do curl -s -m 3 -o /dev/null -w "http %{http_code}\n" http://10.23.1.100/; done'
```
Four times `http 200`; web-3 shows `MAINT`. Now the lasting fix for the monitor: load a configuration whose monitor asks for the real page, `GET /` (`changes/haproxy-check-page.cfg`; BIG-IP: a monitor whose send string asks for the real page and checks the answer). `reload.sh` checks the file first and prints `Configuration file is valid`, then loads it. Wait 5 seconds:
```
docker exec clab-load-balancer-troubleshooting-lb sh /neo/scripts/reload.sh /neo/changes/haproxy-check-page.cfg
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' | cut -d, -f1,2,18,37,38,44 | grep pool_web
```
web-3 is now `DOWN,L7STS,500`: the monitor itself sees the failing page, and would have taken web-3 out without you. (The reload also forgot the `MAINT` setting: run-time changes are not saved.) Repair the application (start web-3's web server normally), then go back to the lesson configuration:
```
docker exec clab-load-balancer-troubleshooting-web-3 pkill -f web_echo.py
```
```
docker exec -d clab-load-balancer-troubleshooting-web-3 sh -c 'python3 -u /neo/scripts/web_echo.py web-3 >>/var/log/web.log 2>&1'
```
```
docker exec clab-load-balancer-troubleshooting-lb sh /neo/scripts/reload.sh /neo/configs/haproxy.cfg
```
(Sample `lbts-2-broken-member.pcapng`, server side: the checks to 10.23.2.13 get `200`, the two requests lb sends there get `500 Internal Server Error`.)

**4. A change took the whole pool down.** A colleague has just loaded a change on the load balancer. Wait 5 seconds after it:
```
bash scripts/fault.sh 3
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s -m 10 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.23.1.100/
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s 'http://10.23.1.1:8404/stats;csv' | cut -d, -f1,2,18,37,38,44 | grep pool_web
```
```
docker exec clab-load-balancer-troubleshooting-lb sh -c "grep '^Server' /var/log/haproxy.log | tail -n 3"
```
```
docker exec clab-load-balancer-troubleshooting-web-1 pgrep -af web_echo.py
```
```
docker exec clab-load-balancer-troubleshooting-lb sh -c "curl -s -m 2 -o /dev/null -w 'GET /health  http %{http_code}\n' http://10.23.2.11/health; curl -s -m 2 -o /dev/null -w 'GET /healthz http %{http_code}\n' http://10.23.2.11/healthz"
```
```
diff configs/haproxy.cfg changes/haproxy-change.cfg
```
`503` at once, as in exercise 2, and all members `DOWN`, but this time with `L7STS,404`: the members **answer** the checks, with `404 Not Found`. The log says `Layer7 wrong status, code: 404, info: "Not Found"`. The web servers run (`pgrep` lists `web_echo.py web-1`), and asked directly they answer `/health` with `200` and `/healthz` with `404`. The last command shows the change: the monitor now asks for `/healthz`, a page these servers do not have. The application is fine; **the monitor is wrong**, and a wrong monitor takes a healthy pool down. When everything fails at once right after a change, look at the change first. Go back to the working configuration (BIG-IP: load the saved configuration, after `verify`):
```
docker exec clab-load-balancer-troubleshooting-lb sh /neo/scripts/reload.sh /neo/configs/haproxy.cfg
```
```
docker exec clab-load-balancer-troubleshooting-client curl -s -m 3 -o /dev/null -w 'http %{http_code}\n' http://10.23.1.100/
```
`Configuration file is valid`, `loaded: /neo/configs/haproxy.cfg`, and the client gets `http 200` again (wait 5 seconds if it still says 503). (Sample `lbts-3-wrong-monitor.pcapng`, server side: the checks change from `GET /health` (200) to `GET /healthz`, and every member answers `404`.)

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open. The server side always carries the health checks (each member every 2 seconds); the display filter `http.response.code != 200` shows only the bad answers.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `lbts-1-app-down.pcapng` | lb:eth1 and lb:eth2 | 122 | the web servers stop: checks to all three members get `[RST, ACK]`; then three requests from 10.23.1.10 to 10.23.1.100 each get `503` from lb, with no connection to a member |
| `lbts-2-broken-member.pcapng` | lb:eth2 (server side) | 165 | six requests through lb: web-1 and web-2 answer `200`, web-3 answers `500` twice, while every health check (`GET /health`) to web-3 still gets `200` |
| `lbts-3-wrong-monitor.pcapng` | lb:eth2 (server side) | 108 | the change is loaded: the checks switch from `GET /health` to `GET /healthz`, and each member answers `404 Not Found` |

## What this lab does not do

- **No F5 BIG-IP.** The `tmsh` commands are text to compare; BIG-IP's GUI, its monitor timing, `/var/log/ltm` and iRules are not here.
- HTTP only, IPv4 only, one load balancer. The faults are made by `scripts/fault.sh`, not by real outages.
- The statistics page is read as CSV from the client; there is no browser in the lab network.

Not affiliated with or endorsed by F5, Inc. or HAProxy Technologies. F5 and BIG-IP are trademarks of F5, Inc. HAProxy is a trademark of HAProxy Technologies. The BIG-IP commands in this folder are text to compare; this lab does not run F5 software.

## Troubleshooting

1. **Exercise 2 shows `UP` members, or the request takes 3 s.** The monitor needs about 6 seconds to mark all three down. Wait 10 seconds after `fault.sh 1` and repeat.
2. **Exercise 3 shows no `500`.** Check that the fault is in place: `docker exec clab-load-balancer-troubleshooting-web-3 pgrep -af web_echo.py` should end in `--broken`. Run `bash scripts/fault.sh 2` again.
3. **`reload.sh` says `NOT loaded`.** The file has an error; HAProxy keeps running with the old configuration. The lines above it name the error.
4. **`hapctl.py` says `No such file or directory`, or nothing answers on 10.23.1.1:8404.** HAProxy is not running on lb: load the lesson configuration with `docker exec clab-load-balancer-troubleshooting-lb sh /neo/scripts/reload.sh /neo/configs/haproxy.cfg`, or reset the lab.
5. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/load-balancer-troubleshooting
```
```
containerlab destroy --cleanup -t load-balancer-troubleshooting.clab.yml
```
`--cleanup` also removes the generated `clab-load-balancer-troubleshooting` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-load-balancer-troubleshooting` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/load-balancer-troubleshooting/clab-load-balancer-troubleshooting
```
Your capture files in your Home folder are not touched.

