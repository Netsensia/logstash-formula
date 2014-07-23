require "test_utils"
require 'pp'

describe "syslog messages", :socket => true do

  extend LogStash::RSpec

  # TODO: Make sure the config files match what we pass to upstart?
  config [ '/etc/logstash/indexer.conf' ].map { |fn| File.open(fn).read }.reduce(:+)

  # Cribbed from https://github.com/elasticsearch/logstash/blob/0d18814d024b4dc65382de7b6e1366381b16b561/spec/inputs/syslog.rb
  input do |pipeline, queue|
    # Stub the time out. Since Syslog doesn't include year in it's dates by
    # default lets make sure we pass past 2014
    Time.stub(:now).and_return(Time.mktime(2014,7,13,19,40,23))

    Thread.new { pipeline.run }
    sleep 0.1 while !pipeline.ready?
    socket = Stud.try(5.times) { TCPSocket.new("127.0.0.1", 2514) }

    context "IP tables logs" do
      Time.stub(:now).and_return(Time.mktime(2014,7,13,19,40,23))

      socket.puts "<5>Jul 8 06:51:09 master.prod1 kernel: [314236.389814] IPTables-Dropped: IN=eth0 OUT= MAC=00:50:56:01:0a:0b:00:50:56:8e:54:fd:08:00 SRC=10.5.12.100 DST=10.5.11.100 LEN=60 TOS=0x00 PREC=0x00 TTL=63 ID=8247 DF PROTO=TCP SPT=54612 DPT=4506 WINDOW=29200 RES=0x00 SYN URGP=0"
      event = queue.pop

      pp JSON.parse(event.to_json)
      reject { event["tags"] || [] }.include? "_grokparsefailure"
      insist { event["message"] } ==  "[314236.389814] IPTables-Dropped: IN=eth0 OUT= MAC=00:50:56:01:0a:0b:00:50:56:8e:54:fd:08:00 SRC=10.5.12.100 DST=10.5.11.100 LEN=60 TOS=0x00 PREC=0x00 TTL=63 ID=8247 DF PROTO=TCP SPT=54612 DPT=4506 WINDOW=29200 RES=0x00 SYN URGP=0"
      insist { event["host"] } == "master.prod1"
      insist { event["type"] } == "syslog"
      insist { event["syslog_facility"] } == "kernel"
      insist { event["syslog_severity"] } == "notice"
      insist { event["syslog_program"] } == "kernel"
      insist { event.timestamp.iso8601 } == "2014-07-08T05:51:09Z"
      # Check that our grok rules worked
      insist { event["dst_port"] } == "4506"
      insist { event["src_port"] } == "54612"

      # Check that the received_at was converted to a proper timestamp, not a string
      insist { event["received_at"].iso8601 } == "2014-07-13T18:40:23Z"

      #puts event.to_json
    end

    describe "haproxy message" do
      socket.puts %q{<134>Jul 9 11:08:50 localhost haproxy[4494]: 81.134.202.29:41294 [09/Jul/2014:11:08:49.463] https~ apps.pvb/apps.pvb1 966/0/0/0/966 200 1599 - - ---- 8/8/0/1/0 0/0 {|Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:30.0) Gecko/20100101 Firefox/30.0} "GET /app/panels/table/micropanel.html HTTP/1.1" {request_id=5186CA1D:A14E_AC1F2FAE:01BB_53BD22C1_1116:118E,- ssl_version=TLSv1.2 ssl_cypher=ECDHE-RSA-AES128-GCM-SHA256}}
      event = queue.pop

      reject { event["tags"] || [] }.include? "_grokparsefailure"
      insist { event["syslog_facility"] } == "local0"
      insist { event["syslog_severity"] } == "informational"
      insist { event["client_ip"] } == "81.134.202.29"
      insist { event["ssl_cypher"] } == "ECDHE-RSA-AES128-GCM-SHA256"
    end

    describe "other messages" do
      socket.puts "<86>Jul 8 12:30:01 ac-front.prod1 CRON[20083]: pam_unix(cron:session): session opened for user accelerated_claims by (uid=0)"
      event = queue.pop

      reject { event["tags"] || [] }.include? "_grokparsefailure"
      insist { event["host"] } == "ac-front.prod1"
      insist { event["type"] } == "syslog"
      insist { event["syslog_facility"] } == "security/authorization"
      insist { event["syslog_program"] } == "CRON"
      insist { event["message"] } == "pam_unix(cron:session): session opened for user accelerated_claims by (uid=0)"
      insist { event.timestamp.iso8601 } == "2014-07-08T11:30:01Z"


    end
  end
end
