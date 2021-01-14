rs232 = require("luars232")
crc16 = require("crc16lua")

port_name = "/dev/ttyVUSB0"

local out = io.stderr

-- open port
local e, p = rs232.open(port_name)
if e ~= rs232.RS232_ERR_NOERROR then
	-- handle error
	out:write(string.format("can't open serial port '%s', error: '%s'\n",
			port_name, rs232.error_tostring(e)))
	return
end

function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

-- set port settings
assert(p:set_baud_rate(rs232.RS232_BAUD_9600) == rs232.RS232_ERR_NOERROR)
assert(p:set_data_bits(rs232.RS232_DATA_8) == rs232.RS232_ERR_NOERROR)
assert(p:set_parity(rs232.RS232_PARITY_NONE) == rs232.RS232_ERR_NOERROR)
assert(p:set_stop_bits(rs232.RS232_STOP_1) == rs232.RS232_ERR_NOERROR)
assert(p:set_flow_control(rs232.RS232_FLOW_OFF)  == rs232.RS232_ERR_NOERROR)

out:write(string.format("OK, port open with values '%s'\n", tostring(p)))

-- read with timeout
local read_len = 4 -- read one byte
local timeout = 4000 -- in miliseconds
local err, data_read, size, str_data

str_data = "4801010101010101012182"
out:write(string.format("init write with timeout: %s\n", str_data))
err, len_written = p:write(str_data:fromhex(), timeout)
assert(e == rs232.RS232_ERR_NOERROR)
out:write(string.format("done write with timeout: %s\n", str_data))

-- read with timeout
out:write("init read with timeout\n")
err, data_read, size = p:read(read_len, timeout)
assert(e == rs232.RS232_ERR_NOERROR)
str_data = data_read:tohex()
out:write(string.format("done read with timeout: %s\n", str_data))

-- close
assert(p:close() == rs232.RS232_ERR_NOERROR)
