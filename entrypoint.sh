#!/usr/bin/env bash

env > /etc/environment
cron
bundler exec ruby -E UTF-8 main.rb
