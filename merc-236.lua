rs232 = require("luars232")
crc16 = require("crc16lua")
cjson = require("cjson")

port_name = arg[1]
local out = io.stderr
local optslist = {}

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

function string.tohex(str, joinwith)
    return (str:gsub('.', function (c)
        return string.format('%02X%s', string.byte(c), joinwith)
    end))
end

function table.torawbin(tbl)
		local rawbin = ""
		for i = 1,#tbl do
			rawbin = rawbin .. string.char(tbl[i])
		end
		return rawbin
end

function addmodbusCRC16(dataPack)
		local hi16, lo16 = CRC16(dataPack)
		table.insert(dataPack, hi16)
		table.insert(dataPack, lo16)
		return dataPack
end

-- read with timeout
local timeout = 8000 -- in miliseconds
local err, data_read, size, str_data

function verblogs(logsline)
		if optslist["verblogs"] ~= 1 then
				return
		end
		out:write(logsline)
end

function executeCommand(dataPack, respSize)
		addmodbusCRC16(dataPack)
		local sendData = table.torawbin(dataPack)
		verblogs(string.format("send (%.2d) -> %s\n", #sendData, string.tohex(sendData, " ")))
		local err, len_written = p:write(sendData, timeout)
		assert(e == rs232.RS232_ERR_NOERROR)
		-- read with timeout
		verblogs(string.format("recv (%.2d) <- ", respSize))
		--
		recvData = ""
		local err, readSZ, tempData
		while #recvData < respSize do
			err, tempData, readSZ = p:read(respSize, 250)
			recvData = recvData .. tempData
		end
		-- local err, data_read, size = p:read(respSize, timeout)
		assert(e == rs232.RS232_ERR_NOERROR)
		verblogs(string.format("%s\n", recvData:tohex(" ")))
		return recvData
end

function bit_lshift(value,n)
	value = value * (2^n)
	return value
end

function parse3Bfloats132(binstr, valind, divide)
	dataV = string.byte(recvData, valind) * 0x10000 + string.byte(recvData, valind + 2) * 0x100 + string.byte(recvData, valind + 1)
	return dataV / divide
end

function fillUvaluesX11(datainfo)
		dbValues = {}

		packSend = {0x00, 0x08, 0x11, 0x11}
		recvData = executeCommand(packSend, 6)
		dbValues["p1"] = parse3Bfloats132(recvData, 2, 100)

		packSend = {0x00, 0x08, 0x11, 0x12}
		recvData = executeCommand(packSend, 6)
		dbValues["p2"] = parse3Bfloats132(recvData, 2, 100)

		packSend = {0x00, 0x08, 0x11, 0x13}
		recvData = executeCommand(packSend, 6)
		dbValues["p3"] = parse3Bfloats132(recvData, 2, 100)

		return dbValues
end

function fillUvaluesX16(datainfo)
		dbValues = {}

		packSend = {0x00, 0x08, 0x16, 0x11}
		recvData = executeCommand(packSend, 12)

		dbValues["p1"] = parse3Bfloats132(recvData, 2, 100)
		dbValues["p2"] = parse3Bfloats132(recvData, 5, 100)
		dbValues["p3"] = parse3Bfloats132(recvData, 8, 100)

		return dbValues
end

function fillIvaluesX16(datainfo)
		dbValues = {}

		packSend = {0x00, 0x08, 0x16, 0x21}
		recvData = executeCommand(packSend, 12)

		dbValues["p1"] = parse3Bfloats132(recvData, 2, 1000)
		dbValues["p2"] = parse3Bfloats132(recvData, 5, 1000)
		dbValues["p3"] = parse3Bfloats132(recvData, 8, 1000)

		return dbValues
end

function fillIvaluesX11(datainfo)
		dbValues = {}

		packSend = {0x00, 0x08, 0x11, 0x21}
		recvData = executeCommand(packSend, 6)
		dbValues["p1"] = parse3Bfloats132(recvData, 2, 1000)

		packSend = {0x00, 0x08, 0x11, 0x22}
		recvData = executeCommand(packSend, 6)
		dbValues["p2"] = parse3Bfloats132(recvData, 2, 1000)

		packSend = {0x00, 0x08, 0x11, 0x23}
		recvData = executeCommand(packSend, 6)
		dbValues["p3"] = parse3Bfloats132(recvData, 2, 1000)

		return dbValues
end


-- set port settings
assert(p:set_baud_rate(rs232.RS232_BAUD_9600) == rs232.RS232_ERR_NOERROR)
assert(p:set_data_bits(rs232.RS232_DATA_8) == rs232.RS232_ERR_NOERROR)
assert(p:set_parity(rs232.RS232_PARITY_NONE) == rs232.RS232_ERR_NOERROR)
assert(p:set_stop_bits(rs232.RS232_STOP_1) == rs232.RS232_ERR_NOERROR)
assert(p:set_flow_control(rs232.RS232_FLOW_OFF)  == rs232.RS232_ERR_NOERROR)

verblogs(string.format("OK, port open with values '%s'\n", tostring(p)))

packSend = {0x00, 0x00}
infoList = {}
infoList["mainstatus"] = 0

executeCommand(packSend, 4)

packSend = {0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01}
executeCommand(packSend, 4)

--infoList["U1"] = fillUvaluesX11()
--infoList["I1"] = fillIvaluesX11()
infoList["U"] = fillUvaluesX16()
infoList["I"] = fillIvaluesX16()

print(cjson.encode(infoList))

-- close
assert(p:close() == rs232.RS232_ERR_NOERROR)
