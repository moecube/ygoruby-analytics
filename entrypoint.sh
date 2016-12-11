#!/usr/bin/env bash

env > /etc/environment
cron
ruby -E UTF-8 main.rb 
