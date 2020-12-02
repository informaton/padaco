function headerStr = generateActigraphHeader(startDatenum,downloadDatenum,epochPeriodSec)
    if(nargin<3)
        epochPeriodSec = 1;
    end
    if(nargin<2 || isempty(downloadDatenum))
        downloadDatenum = now;
    end
    defaults = {'firmware', 'v2.5.0'
                'serial_number', ['NEO1C15', datestr(now, 'yymmdd')]
                'start_time', '00:00:00'
                'download_date', datestr(now, 'mm/dd/yyyy')
                
                
    downloadTimeStr = datestr(downloadDatenum,'HH:MM:SS');
    downloadDateStr = datestr(downloadDatenum,'mm/dd/yyyy');
    startTimeStr = datestr(startDatenum,'HH:MM:SS');
    startDateStr = datestr(startDatenum,'mm/dd/yyyy');
    
    epochPeriodStr = datestr(epochPeriodSec/24/3600,'HH:MM:SS');
    headerStr = sprintf(['------------ Data Table File Created By ActiGraph GT3XPlus ActiLife v6.10.2 Firmware v2.5.0 date format M/d/yyyy Filter Normal -----------',...
        '\nSerial Number: NEO1C15110116',...
        '\nStart Time %s',...
        '\nStart Date %s',...
        '\nEpoch Period (hh:mm:ss) %s',...
        '\nDownload Time %s',...
        '\nDownload Date %s',...
        '\nCurrent Memory Address: 0',...
        '\nCurrent Battery Voltage: 3.9     Mode = 61',...
        '\n--------------------------------------------------',...
        '\nDate,Time,Axis1,Axis2,Axis3,Steps,Lux,Inclinometer.Off,Inclinometer.Standing,Inclinometer.Sitting,Inclinometer.Lying,Vector.Magnitude'],...
        startTimeStr,startDateStr,epochPeriodStr,downloadTimeStr,downloadDateStr);
end

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