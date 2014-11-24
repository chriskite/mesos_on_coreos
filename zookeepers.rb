#!/usr/bin/env ruby
require 'open-uri'
require 'json'

exhibitor_host = ARGV.first
exhibitor_url = "http://#{exhibitor_host}/exhibitor/v1/cluster/list"
json = open(exhibitor_url).read
data = JSON.parse(json)
print data['servers'].map { |s| "#{s}:#{data['port']}" }.join(',')
