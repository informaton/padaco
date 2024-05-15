function [axes_data, datenums]= getActigraphRecordsFromBin(binFilename, recordTypeToGet, accelerationScale, sampleRate, numAxesPerRecord)
    narginchk(1,5);

    axes_data = [];
    datenums = [];

    ACTIVITY1_ID = 0;   % this is for the three axis of
                        % accelarations in 12 bit precision in y,x,z order
                        % in the actigraphy format, but transformed to x,y,z order here
    ACTIVITY2_ID = 26; % activity as x,y,z in sort, little-endian order

    if nargin<2 || isempty(recordTypeToGet)
        recordTypeToGet = ACTIVITY2_ID; 
    end

    % Scale the resultant by the scale factor (this gives us an acceleration value in g's). Device serial numbers starting with NEO and CLE use a scale factor of 341 LSB/g (±6g). MOS devices use a 256 LSB/g scale factor (±8g). If a LOG_PARAMETER record is preset, then the ACCEL_SCALE value should be used.
    if nargin<3 || isempty(accelerationScale)
        % the number of bits per unit of graphic
        % The number of bits applied to the dynamic range
        % +/- 6g with 12 bits is going to be 12g/(2^12) = 0.0029..  or
        % (2^12bits)/12g = 341.33333 = 341
        % +/- 8g with 12 bits is going to be 2^12/16g = 2^16/2^4 = 2^8 = 256
        accelerationScale = 341; %from trial and error - or math: 
    end

    if nargin<5 || isempty(numAxesPerRecord)
        numAxesPerRecord = 3;
    end

    fid = fopen(binFilename,'r');
    if fid>0
        try
            recordCount = fgetactigraphrecordcount(fid, recordTypeToGet);
            recordCount = recordCount*sampleRate;
            if recordCount > 0
                frewind(fid);
                [axesBitData, timestamps_unix] = fgetactigraphaxesrecords(fid, recordTypeToGet, recordCount, numAxesPerRecord);
                if recordTypeToGet==ACTIVITY1_ID
                    axes_data = (-bitand(axesBitData,2048)+bitand(axesBitData,2047))/accelerationScale;
                    axes_data = [axes_data(:,2), axes_data(:,1), axes_data(:,3)];  % transforms [y,x,z] --> [x, y, z]
                    % axes_float_data = (-bitand(axesUBitData,2^(bitsPerAxis-1))+bitand(axesUBitData,2^(bitsPerAxis-1)-1))*encodingEPS;
                elseif recordTypeToGet == ACTIVITY2_ID
                    axes_data = axesBitData/accelerationScale;
                    % axes_float_data = (-bitand(axesUBitData,2^(bitsPerAxis-2),'int16')+bitand(axesUBitData,2^(bitsPerAxis-2)-1,'int16'))*encodingEPS;
                else
                    axes_data = axesBitData;
                end
                datenums = timestampunix2datenums(timestamps_unix);
            end
        catch me
            showME(me);
        end
        fclose(fid);
    else
        warning('File could not be opened for reading: %s', binFilename);
    end

end
