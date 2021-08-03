band mode switch

It happens that the 4G base station has a high load, but the modem automatically selects the best signal, while the WCDMA network is more free.
This script solves the problem and automatically switches the network type AUTO <-> WCDMA.

Add a rule to cron
*/30 18-01  * * * /root/switch_4g_umts_band.sh
