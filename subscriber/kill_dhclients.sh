#!/usr/bin/env sh

ps -ef | grep dhclient | grep -v -e grep | awk '{print "sudo kill -9", $2}' |sh
