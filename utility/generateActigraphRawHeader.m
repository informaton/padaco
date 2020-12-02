function headerStr = generateActigraphRawHeader(startDatenum,varargin)

    defaults = {'firmware', 'v2.5.0'
                'actilife_version', 'v6.11.4'
                'sampling_frequency', 40
                'serial_number', ['NEO1C15', datestr(now, 'yymmdd')]
                'download_date', datestr(now, 'mm/dd/yyyy')
                'download_time', datestr(now, 'HH:MM:SS')                
                'epoch_period', '00:00:00'
                'filter', 'Normal'
                'mode', '12'
                };
            
    p = parse_pv_pairs(mkstruct(defaults(:,1), defaults(:,2)), varargin);
    
    if isVerLessThan(p.actilife_version, 'v6.12.0')        
        axisHeader = 'Timestamp,Axis1,Axis2,Axis3';
    else
        axisHeader = 'Accelerometer X,Accelerometer Y,Accelerometer Z';
    end

            
    startTimeStr = datestr(startDatenum,'HH:MM:SS');
    startDateStr = datestr(startDatenum,'mm/dd/yyyy');
    headerStr = sprintf([
        '------------ Data File Created By ActiGraph GT3X+ ActiLife %s Firmware %s date format M/d/yyyy at %d Hz  Filter %s -----------', ...
        '\nSerial Number: %s',...
        '\nStart Time %s',...
        '\nStart Date %s',...
        '\nEpoch Period (hh:mm:ss) %s',...
        '\nDownload Time %s',...
        '\nDownload Date %s',...
        '\nCurrent Memory Address: 0',...
        '\nCurrent Battery Voltage: 3.9     Mode = %s',...
        '\n--------------------------------------------------',...
        '\n%s'],...
        p.actilife_version, p.firmware, p.sampling_frequency, p.filter, ...
        p.serial_number, startTimeStr,startDateStr,p.epoch_period, ...
        p.download_time, p.download_date, p.mode, axisHeader);
end

function isIt = isVerLessThan(ver1, ver2)
    ver1Parts = getParts(ver1);
    ver2Parts = getParts(ver2);
    if ver1Parts(1) ~= ver2Parts(1)     % major version
        isIt = ver1Parts(1) < ver2Parts(1);
    elseif ver1Parts(2) ~= ver2Parts(2)     % minor version
        isIt = ver1Parts(2) < ver2Parts(2);
    else   % minor version
        isIt = ver1Parts(3) < ver2Parts(3);
    end    
end

function parts = getParts(V)
    parts = sscanf(V, 'v%d.%d.%d')';
    if length(parts) < 3
        parts(3) = 0; % zero-fills to 3 elements
    end
end

% Data File Created By ActiGraph GT3X+ ActiLife v6.13.3 Firmware v2.2.1 date format M/d/yyyy at 40 Hz  Filter Normal
% Accelerometer X,Accelerometer Y,Accelerometer Z


% Example
% ------------ Data File Created By ActiGraph GT3X+ ActiLife v6.11.4 Firmware v2.5.0 date format M/d/yyyy at 40 Hz  Filter Normal -----------
% Serial Number: NEO1C15110103
% Start Time 00:00:00
% Start Date 10/7/2012
% Epoch Period (hh:mm:ss) 00:00:00
% Download Time 18:55:05
% Download Date 10/17/2012
% Current Memory Address: 0
% Current Battery Voltage: 2.53     Mode = 12
% --------------------------------------------------
% Timestamp,Axis1,Axis2,Axis3