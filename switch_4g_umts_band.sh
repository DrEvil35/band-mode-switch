#!/bin/sh

MODEM='/dev/ttyUSB3'

IPERF_HOST='speedtest.hostkey.ru'
IPERF_PORT=5200
IPERF_TRY=5

MODE_AUTO=0
MODE_WCDMA=2
INTERFACE=LTE

MIN_SPEED=6

. /usr/share/libubox/jshn.sh

function at(){
	echo AT | atinout - ${MODEM} - > /dev/null
	echo $( echo "$1" | atinout - ${MODEM} - )
}

function speed_test(){
	local speed=0
	for i in $(seq 1 $1); do
		local json_res="$(iperf3 -c ${IPERF_HOST} -p ${IPERF_PORT} -t3  -J -Z --forceflush)"
		#echo $json_res >&2
		json_load "$json_res"
		json_get_var error_string "error"
		if [ ! -z "$error_string" ];then
			logger -t "Band control" "Error iperf: $error_string"
			speed=0
			sleep 1
			continue
		fi
		json_select "end"
		json_select "streams"
		json_select "1"
		json_select "receiver"
		json_get_var speed "bits_per_second"
		speed=$(($(printf "%.0f" $speed)/1000000)) 
		echo "Speed: $speed Mb/s" >&2
		break
	done
	echo $speed
}

function get_mode(){
        echo $( at AT+QCFG=\"nwscanmode\" | sed -nE 's/.*\+QCFG: "nwscanmode",(.{1}).*/\1/p' ) 
}

function is_connected(){
	[ -z $( at AT+CGPADDR | sed -nE 's/.*\+CGPADDR: .{1},"(\d{1,3}\.\d{1,3}\.\d{1,3}.\d{1,3})".*/\1/p' | xargs ) ] && echo 1 || echo 0
}

function set_modem_mode(){
	echo "Set mode $(get_mode) => $1" >&2
	[ "$1" -eq "$(get_mode)" ] && return 0
	logger -t 'Band control' "Change mode $1"
	ifdown "$INTERFACE"
	logger -t 'Band control' $(echo at AT+QCFG=\"nwscanmode\",${1},1 )
	sleep 1
	ifup "$INTERFACE"
	while [ $(is_connected) == "0" ] ;do
	sleep 1
	done
	return 1
}


function switch_band(){
	local band_mode=$(get_mode)
	local speed1=$(speed_test $IPERF_TRY)
	[ $speed1 -eq "0" ]  && return 1
	logger -t 'Band control' "Test speed LTE $speed1 mode $band_mode"
	if [ $speed1 -gt $MIN_SPEED ];then
		set_modem_mode $MODE_AUTO
	else
		if [ $band_mode == $MODE_WCDMA ];then
			set_modem_mode $MODE_AUTO
		else	
			set_modem_mode $MODE_WCDMA
		fi
	fi
	[ $? -eq "0" ] && return 1
	local speed2=$(speed_test $IPERF_TRY)
	[ $speed2 -eq "0" ] && return 1
	logger -t 'Band control' "Changed speed $speed1 => $speed2"
	if [ $speed1 -ge $speed2 ];then
		set_modem_mode $band_mode
	fi
}


if [ ! $( at AT |  grep -q OK ) ] && [ $(is_connected) ] ;then
	switch_band
fi
