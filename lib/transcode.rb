class Transcode
  require 'socket'
  require 'timeout'
  require 'ipaddr'

  SOCKET_BLOCK = 1400

  # Board errors
  RET_OK = 1
  RET_ERROR = 2
  RET_EFORMAT = 3
  RET_EVALUE = 4
  RET_ERES = 5

  # Internal errors
  RET_SOCKET = 254

  # Commands
  MOD_GET_SLOTS = 1
  MOD_GET_NET_CONFIG = 2
  MOD_SET_NET_CONFIG = 3
  MOD_MOD_RESTART = 4
  MOD_CREATE_SLOT = 5
  MOD_REMOVE_SLOT = 6
  MOD_GET_SLOT = 7
  MOD_SAVE_CONFIG = 8
  MOD_SLOT_CMD = 9

  # Commands for MOD_SLOT_CMD
  CMD_SLOT_GET_STATUS = 101
  CMD_SLOT_STOP = 102
  CMD_SLOT_RESTART = 103

  # Slot status ???
  SLOT_STOPPED = 0
  SLOT_RUNNING = 1

  def initialize(options)
    @host = options.delete(:host)
    @port = options.delete(:port)
    @debug = options.delete(:debug)
    @timeout = 5
  end

  def mod_get_slots
    error, response, command = send_request('C', MOD_GET_SLOTS)
    return {error: error, message: response, command: command, response: response,} if error != RET_OK

    unpacked = response.unpack('CC*')
    response_code, slots_cnt, slot_ids = [unpacked[0], unpacked[1], unpacked[2..-1]]
    error == RET_OK ?
        {error: response_code, message: get_error(response_code), command: command, response: response,
         result: {slots_cnt: slots_cnt, slots_ids: slot_ids[0... slots_cnt]}}
    :
        {error: response_code, message: get_error(response_code), command: command, response: response}
  end

  def mod_get_net_config(slot_id)
    command = MOD_GET_NET_CONFIG
    error, response, real_command = send_request(command)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    unpacked = response.unpack('CNNNNN')
    response_code, ip1, netmask1, ip2, netmask2, gateway = [unpacked[0], unpacked[1], unpacked[2], unpacked[3], unpacked[4]]
    return {error: response_code, message: get_error(response_code), command: command, response: response} if response_code != RET_OK

    ip1 = IPAddr.new ip1, Socket::AF_INET
    ip2 = IPAddr.new ip2, Socket::AF_INET
    netmask1 = IPAddr.new netmask1, Socket::AF_INET
    netmask2 = IPAddr.new netmask2, Socket::AF_INET
    gateway = IPAddr.new gateway, Socket::AF_INET
    {error: response_code, message: get_error(response_code), command: command, response: response,
     result: {ip1: ip1.to_s, netmask1: netmask1, ip2: ip2.to_s, netmask2: netmask2, gateway: gateway}
    }
  end

  def mod_restart
    error, response, real_command = send_request('C', MOD_RESTART)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    response_code = response.unpack('C')[0]
    {error: response_code, message: response_code == RET_OK ? "Module was (re)started" : "Module was NOT (re)started", command: command, response: response}
  end

  def mod_create_slot(slot_id, force, tracks_cnt, tracks)
    error, response, command = send_request('CCCCC*', MOD_CREATE_SLOT, slot_id, force, tracks_cnt, tracks)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    response_code = response.unpack('C')[0]
    {error: response_code, message: response_code == RET_OK ? "Slot #{slot_id} was created" : "Slot #{slot_id} was NOT created", command: command, response: response}
  end

  def mod_remove_slot(slot_id)
    error, response, command = send_request('CC', MOD_REMOVE_SLOT, slot_id)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    response_code = response.unpack('C')[0]
    {error: response_code, message: response_code == RET_OK ? "Slot #{slot_id} was removed" : "Slot #{slot_id} was NOT removed", command: command, response: response}
  end

  def mod_get_slot(slot_id)
    error, response, command = send_request('CC', MOD_GET_SLOT, slot_id)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    unpacked = response.unpack('CCCN*')
    response_code, force, tracks_cnt, tracks = [unpacked[0], unpacked[1], unpacked[2], unpacked[3..-1]]
    {error: response_code, message: get_error(response_code), command: command, response: response} if response_code != RET_OK

    tracks = tracks[0... tracks_cnt].map do |track|
      [track].pack('N').unpack('C*')
    end

    {error: response_code, message: get_error(response_code), command: command, response: response,
     result: {force: force, total_tracks: tracks_cnt, tracks: tracks}
    }
  end

  def mod_slot_get_status(slot_id)
    error, response, command = send_request('CCC', MOD_SLOT_CMD, slot_id, CMD_SLOT_GET_STATUS)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    unpacked = response.unpack('CCCNNNNNCC*')
    response_code, slot_status, signal, uptime, ip1, port1, ip2, port2, tracks_cnt, tracks =
        [unpacked[0], unpacked[1], unpacked[2], unpacked[3], unpacked[4], unpacked[5], unpacked[6], unpacked[7], unpacked[8], unpacked[9..-1]]
    {error: response_code, message: get_error(response_code), command: command, response: response} if response_code != RET_OK

    {error: RET_OK, message: "Slot is stopped", command: command, response: response} if slot_status == SLOT_STOPPED

    ip1 = IPAddr.new ip1, Socket::AF_INET
    ip2 = IPAddr.new ip2, Socket::AF_INET
    tracks = tracks[0... tracks_cnt]

    {error: response_code, message: get_error(response_code), command: command, response: response,
     result: {signal: signal, uptime: uptime, ip1: ip1.to_s, port1: port1, ip2: ip2.to_s, port2: port2, total_tracks: tracks_cnt, tracks: tracks}
    }
  end

  def mod_slot_stop(slot_id)
    error, response, command = send_request('CCC', MOD_SLOT_CMD, slot_id, CMD_SLOT_STOP)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    response_code = response.unpack('C')[0]
    {error: response_code, message: response_code == RET_OK ? "Slot #{slot_id} was stopped" : "Slot #{slot_id} was NOT stopped", command: command, response: response}
  end

  def mod_slot_restart(slot_id, ip1, port1, ip2, port2, tracks_cnt, tracks)
    ip1 = IPAddr.new ip1, Socket::AF_INET
    ip2 = IPAddr.new ip2, Socket::AF_INET
    error, response, command = send_request('CCCNNNNCC*', MOD_SLOT_CMD, slot_id, CMD_SLOT_RESTART, ip1.to_i, port1, ip2.to_i, port2, tracks_cnt, tracks)
    return {error: error, message: response, command: command, response: response} if error != RET_OK

    response_code = response.unpack('C')[0]
    {error: response_code, message: response_code == RET_OK ? "Slot #{slot_id} was (re)started" : "Slot #{slot_id} was NOT (re)started", command: command, response: response}
  end

  private
  def send_request(pack_mask, *command)
    socket = nil

    begin
      timeout(@timeout) do # the server has timeout seconds to answer
        socket = TCPSocket.open(@host, @port)
      end
    rescue
      return [RET_SOCKET, "#{$!}"]
    end

    begin
      real_command = command.flatten.pack(pack_mask)
      socket.send real_command, 0
      response = socket.recv(SOCKET_BLOCK)
    rescue
      return [RET_SOCKET, "#{$!}"]
    ensure
      socket.close
    end

    [RET_OK, response, real_command]
  end


  def get_error(error_code, message = nil)
    case error_code
      when RET_OK
        'Command completed successfully'
      when RET_ERROR
        'Internal error when processing command'
      when RET_EFORMAT
        'Bad format of request message'
      when RET_EVALUE
        'Bad value of some parameter in request message'
      when RET_ERES
        'Not enough resources to create slot'
      else
        message
    end
  end

end
