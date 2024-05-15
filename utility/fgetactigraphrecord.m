% Reference: https://github.com/actigraph/GT3X-File-Format/blob/main/README.md
function record = fgetactigraphrecord(fid)
    SEPARATOR_D = 30;
    separator = fread(fid,1,'uint8');
    record = [];

    % See reference note re rare cases where a series of 0 values may be
    % found between valid records and can be ignored because the data is
    % not corrupted.  
    while ~feof(fid) && separator==0
        separator = fread(fid,1,'uint8');
    end

    if ~feof(fid)
        
        if separator ~= SEPARATOR_D
            warning('Warning separator does not match expected value.\n');
        else
            record = struct();
            record.activityType = fread(fid,1,'uint8');
            record.timeStamp = fread(fid,1,'uint32=>double');
            record.payloadSz = fread(fid,1,'uint16','l');
            % record.payloadSz = fread(fid, 2, 'uint8');
            record.payload = fread(fid, record.payloadSz, 'uint8');
            record.checksum = fread(fid, 1, 'uint8');
        end
    end
end

% Acitivity 
% 0	0x00	ACTIVITY	One second of raw activity samples packed into 12-bit values in YXZ order.
% 2	0x02	BATTERY	Battery voltage in millivolts as a little-endian unsigned short (2 bytes).
% 3	0x03	EVENT	Logging records used for internal debugging. These records notably contain information about idle sleep mode. When entering idle sleep mode, a record with payload 0x08 is created. When existing idle sleep mode, a record with payload 0x09 is created.
% 4	0x04	HEART_RATE_BPM	Heart rate average beats per minute (BPM) as one byte unsigned integer.
% 5	0x05	LUX	Lux value as a little-endian unsigned short (2 bytes).
% 6	0x06	METADATA	Arbitrary metadata content. The first record in every log is contains subject data in JSON format.
% 7	0x07	TAG	13 Byte Serial, 1 Byte Tx Power, 1 Byte (signed) RSSI
% 9	0x09	EPOCH	60-second epoch data
% 11	0x0B	HEART_RATE_ANT	Heart Rate RR information from ANT+ sensor.
% 12	0x0C	EPOCH2	60-second epoch data
% 13	0x0D	CAPSENSE	Capacitive sense data
% 14	0x0E	HEART_RATE_BLE	Bluetooth heart rate information (BPM and RR). This is a Bluetooth standard format.
% 15	0x0F	EPOCH3	60-second epoch data
% 16	0x10	EPOCH4	60-second epoch data
% 21	0x15	PARAMETERS	Records various configuration parameters and device attributes on initialization.
% 24	0x18	SENSOR_SCHEMA	This record allows dynamic definition of a SENSOR_DATA record format.
% 25	0x19	SENSOR_DATA	This record stores sensor data according to a SENSOR_SCHEMA definition.
% 26	0x1A	ACTIVITY2	One second of raw activity samples as little-endian signed-shorts in XYZ order.