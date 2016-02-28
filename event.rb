#!/usr/bin/ruby
#
require 'socket'
#require 'iconv'
require 'pp'

##############################################################################
# Log function
##############################################################################
def log(str)
  puts str
end
##############################################################################


##############################################################################
# Parse config file
##############################################################################
def parseConfig(conffile)
  hash = {}
  begin
    IO.foreach(conffile) do |line|
      unless Regexp.compile('^#.*').match(line)
        option, value = line.chomp.split(/\s*=\s*/)
        hash[option.strip] = value unless option.nil? or value.nil?
      end
    end
  rescue => error
    log "#{error}"
  end
  return hash
end
##############################################################################

##############################################################################
# Open TCP connection
##############################################################################
def connect
  tcpSock = TCPSocket.new $app["hostname"], $app["port"]
  return tcpSock
end
##############################################################################


##############################################################################
# Get authenticate
##############################################################################
def login tcpSock
  begin
    tcpSock.write "Action: Login\r\n"
    tcpSock.write "UserName: #{$app["username"]}\r\n"
    tcpSock.write "Secret: #{$app["password"]}\r\n"
    # We don't need Events yet
    events(tcpSock, "off")
  rescue => error
    log "#{error}"
  end
end
##############################################################################

##############################################################################
# Set events type
# Event type: TODO:
##############################################################################
def events tcpSock, action
  begin
    tcpSock.write "Action: Events\r\n"
    tcpSock.write "EventMask: #{action}\r\n\r\n"
  rescue => error
    log "#{error}"
  end
end
##############################################################################


##############################################################################
# Get next block until empty line
##############################################################################
def getBlock tcpSock
  block = {}
    until tcpSock.nil?
        line = tcpSock.gets.chomp
    break if line.empty?
    option, value = line.split(/:\s*/)
    block[option.strip] = value unless option.nil? or value.nil?
  end
return block
end
##############################################################################




##############################################################################
# Parse Link event of Agent call
##############################################################################
def parseLink block

#    log "parseLink #{block["Uniqueid1"]}\n"
    puts "\n --- ParseLink start ---\n"
#    pp block
    pp $calls.inspect


  if  block["Bridgestate"].include? "Link" and
    not ($calls.has_value? block["Uniqueid1"]) and 
    block["Channel2"].include? "SIP/"
    
    pp block
    pp $calls.inspect
    pp block["Uniqueid1"]

    $from = block["CallerID1"]
    $to = block["CallerID2"]
    $id = block["Uniqueid1"]
#    $calls.inspect

    #      log "call\n"
    puts "\n ---- bridge link for call ----- \n"

 if($to.size < 6)
    pp $from
    pp $to
    pp $id

    if($from.size == 12)
    pp "curl -k --max-time 3 'https://" + $app["link"] + "/rest/register_call/?phone=+" + $from + "&direction=incoming&comment=" + $id + "&internal_phone=" + $to + "&ukey=" + $app["ukey"] + "&tz=3'"
        puts system("curl -k --max-time 3 'https://" + $app["link"] + "/rest/register_call/?phone=+" + $from + "&direction=incoming&comment=" + $id + "&internal_phone=" + $to + "&ukey=" + $app["ukey"] + "&tz=3'")

    else
        pp $from
    end

    else
    block["Channel1"][/\/(\d+)-/]
    $from=$1
    pp $from
    pp $to
    pp $id
    pp "curl -k --max-time 3 'https://" + $app["link"] + "/rest/register_call/?phone=+" + $to + "&direction=outgoing&comment=" + $id + "&internal_phone=" + $from + "&ukey=" + $app["ukey"] + "&tz=3'"
    puts system("curl -k --max-time 3 'https://" + $app["link"] + "/rest/register_call/?phone=" + $to + "&direction=outgoing&comment=" + $id + "&internal_phone=" + $from + "&ukey=" + $app["ukey"] + "&tz=3'")

    end
    $calls[block["Uniqueid1"]]= block["Uniqueid1"]
    puts "\n --- ParseLink end ---\n"
    pp $calls.inspect
    end
end
##############################################################################

##############################################################################
# Handle call to Agent peer
# TODO: Add implementation
##############################################################################
def delCall call
  # Check if block has Agent channel
      puts " ---  del call  start ----\n"
      pp call
      puts " ---  call delete ----\n"
            $calls.delete(call[Uniqueid])
             pp $calls.inspect
      puts " --- end ----\n"
end
##############################################################################
# Proceed some initial stuff
##############################################################################
def main
  $app = parseConfig "call_notifier.conf"
  #pp $app
  puts "--------------------------------------\n"

  tcpSock = connect

  ##############################################
  #############################################################################
  unless tcpSock.nil?
    login tcpSock
    # Turn off events
    events tcpSock, "off"

    $uniqueID = {}
    $calls = {}
    $delay = 2

    # Turn on call and system events
    events tcpSock, "dialplan,call,system"
    ###########################################################################


    ###########################################################################
    # Start main loop
    # TODO: add kill handler here instead of loop
    # TODO: add parse of PeerEntry
    ###########################################################################
    until tcpSock.nil?
      block = getBlock tcpSock
      #########################################################################
      # Parse event
      #########################################################################

#     pp block
#      log "Event: #{block["Event"]}"
      case block["Event"]
        # Agent call
      when "HangupRequest"
        delCall block
      when "Bridge"
        parseLink block
#pp block

      end if block.has_key? "Event" #case

    end
    tcpSock.close
  end
end
##############################################################################

##############################################################################
# Procee main stuff
##############################################################################
$delay = 2
while true
  begin
    main
  rescue Exception => ex
    log "ERROR: #{ex} retry for #{$delay} seconds"
  end
  sleep $delay
  $delay += $delay if $delay <= 60
end
##############################################################################

