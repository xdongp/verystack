#!/bin/sh
wget http://lg-pt-controlnode01.bj/script/cpulimit
wget http://lg-pt-controlnode01.bj/script/kvmlimit
mv cpulimit /usr/bin
mv kvmlimit /usr/bin
chmod +x /usr/bin/cpulimit
chmod +x /usr/bin/kvmlimit

crontab  -l > /tmp/crontab.txt
echo "" >> /tmp/crontab.txt
echo "#限制CPU使用" >> /tmp/crontab.txt
echo "*/3 * * * * kvmlimit &>/root/kvmlimit.log" >> /tmp/crontab.txt
cat  /tmp/crontab.txt | crontab