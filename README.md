# keepalived-notes
keepalived is based on the [VRRP](https://en.wikipedia.org/wiki/Virtual_Router_Redundancy_Protocol) protocol which is used for many redundant and high availability scenarios. 

https://www.keepalived.org/   
https://github.com/acassen/keepalived


This guide will setup a 2 node cluster with a floating IP (also known as a Virtual IP or VIP) and will watchdog a service via REST and perform an action up on failover via REST as well. 
> You can setup a 3 node cluster with 1 MASTER and 2 BACKUPs following the same guide. Just add another BACKUP and update the `unicast_peers`. 

> This guide assumes there is a web server at http://localhost:80 that will be health checked via HTTP GET. Run something like nginx to test this. 

keepalived works on many linux versions. In this guide we will be installing on Rocky Linux 9.

### References for this guide
* [keepalived man page](https://www.keepalived.org/manpage.html)
* [DigitalOcean keepalived guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-highly-available-web-servers-with-keepalived-and-reserved-ips-on-ubuntu-14-04#creating-the-primary-server-s-configuration)
* [Kubernetes HA with keepalived](https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#keepalived-configuration)
* [tobru check and notify scripts](https://tobru.ch/keepalived-check-and-notify-scripts/)
* [RedHat keepalived docs](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/load_balancer_administration/ch-initial-setup-vsa)
    * [RedHat keepalived basics](https://www.redhat.com/sysadmin/keepalived-basics)


## Install keepalived
Install keepalived on all nodes.
```
yum install keepalived
```
The scripts for this setup use `curl` to check a REST API. If you don't have `curl` install it.
```
yum install curl
```

### Optional extras 
There's a keepalived syntax file for vim that might be helpful in development environments.
https://github.com/glidenote/keepalived-syntax.vim

* Drop the `keepalived.vim` file into   
`/usr/share/vim/vim82/syntax/keepalived.vim`
* Add the following line to ~/.vimrc:   
`au BufRead,BufNewFile keepalived.conf setlocal ft=keepalived`
* It might also be useful to set your tabs to 4 spaces by adding `set tabstop=4` to   
`~/.vimrc`

## Setup Cluster

### Prepare 

Move the default keepalived.conf 
```
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.default
```

Add a "keepalived_user" which will execute health checks on monitored services (via vrrp_script). See config for why this is done. 
```sh
groupadd -r keepalived_script
useradd -r -s /sbin/nologin -g keepalived_script -M keepalived_script
```

### Determine IPs
Determine what your servers IPs are and what the floating IPs are and which one is master/primary. For this setup:

- Server A: 192.168.1.46 (master/primary)
- Server B: 192.168.1.47 (backup)
- Floating IP: 192.168.1.50

### Identify Interfaces
For this test both servers are using `eth0`. 

In production you may have a dedicated network for HA with it's own interfaces. This is recommended but not required.

##  Load Scripts and Configs
Add the following files to `/etc/keepalived/` for all servers.
* keepalived.conf
    * [keepalived.conf.master](keepalived.conf.master)
    * [keepalived.conf.backup](keepalived.conf.backup)
* [check_api.sh](check_api.sh)
* [handle_state_change.sh](handle_state_change.sh)

Make the two scripts executable by running: 
```
chmod +x /etc/keepalived/check_api.sh
chmod +x /etc/keepalived/handle_state_change.sh
chown keepalived_script:keepalived_script /etc/keepalived/check_api.sh
chown keepalived_script:keepalived_script /etc/keepalived/handle_state_change.sh
```

(Optional) If you want handle_state_change.sh to write to it's log, make that file and allow keepalived_script to write to it. Otherwise, comment out that capability in the script. 
```
touch /var/log/keepalived_state.log
chown keepalived_script:keepalived_script /var/log/keepalived_state.log
```

Test that the configs are working with: 
```
keepalived --config-test
```

## Start Cluster
Keepalived logs to syslog/messages. Tail it before starting.
```
tail -f /var/log/messages
```

Enable and Start keepalived by running:
```
systemctl enable keepalived
systemctl start keepalived
```

## Testing Failover
You can test a failover by stopping the webserver on the master to force a failover. You'll see the floating IP swap over and if your webservers are hosting unique pages (e.g. with the server name) you'll see that change too.

If you start the keepalived service on the master again, the floating IP will move back to master after a few seconds. You can disable return to master with `nopreempt` in the configs.

## Checking Keepalived Status

Take a look at your interface to see when the floating IP is present, indicating master.    
```
ip a
```

Systemctl can also tell you the status of keepalived.
```
systemctl status keepalived
```

keepalived can also be triggered to write status and statistics to files by sending signals to the keepalived binary. 

### Keepalived Data Query
If you send a `USR1` signal to keepalived it will write status data to /tmp/keepalived.data. The safest way to do this is to ask keepalived for the correct signal number, as some kernels change the number.

To get the statistics data run the following:
```
kill -s $(keepalived --signum=DATA) $(cat /run/keepalived.pid); cat /tmp/keepalived.data
```
This returns a ton of data, which you can filter/grep across. To get the current state of a server/node run:
```
kill -s $(keepalived --signum=DATA) $(cat /run/keepalived.pid); cat /tmp/keepalived.data | grep State
```
Which returns:
```
State = BACKUP
```

### Keepalived Stats Query
Sending `USR2` signal to keepalived writes statistics to /tmp/keepalived.stats. Again ask keepalived for the signal number. 

```
 kill -s $(keepalived --signum=STATS) $(cat /run/keepalived.pid); cat /tmp/k
eepalived.stats
```
Which returns: 
```
VRRP Instance: VI_1
  Advertisements:
    Received: 3
    Sent: 41291
  Became master: 2
  Released master: 1
  Packet Errors:
    Length: 0
    TTL: 0
    Invalid Type: 0
    Advertisement Interval: 0
    Address List: 0
  Authentication Errors:
    Invalid Type: 0
    Type Mismatch: 0
    Failure: 0
  Priority Zero:
    Received: 0
    Sent: 1
```

You can reset these stats with: 
```
kill -s $(keepalived --signum=STATS_CLEAR) $(cat /run/keepalived.pid)
```
### Advanced Monitoring
Keepalived supports monitoring via SNMP GETs or SNMP Traps as well as notifications to be sent over email/SMTP. You can also hook into the `notify` script to do advanced notifications via bash. 

Take a look at the `global_defs` section of the keepalived man page for more details on how to set this up.
https://www.keepalived.org/manpage.html
