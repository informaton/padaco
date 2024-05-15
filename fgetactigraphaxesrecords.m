% retrieves activity or activity2 data from an open file handle of an
% actigraph .bin file (e.g. log.bin)
% axesUBitData is unsigned for activity1 type
% axesUBitData is signed for actvitiy2 type
function [axesUBitData, timestamps] = fgetactigraphaxesrecords(fid, RECORD_TYPE_ID, recordCount, NUM_AXES_PER_RECORD)
    narginchk(2,4);

    ACTIVITY1_ID = 0;   % this is for the three axis of
                        % accelarations in 12 bit precision.
    ACTIVITY2_ID = 26; % activity as x,y,z in sort, little-endian order

    if nargin<3 || isempty(recordCount)
        recordCount = fgetactigraphrecordcount(fid, RECORD_TYPE_ID);
    end

    if nargin<4 || isempty(NUM_AXES_PER_RECORD)
        NUM_AXES_PER_RECORD = 3;
    end

    if RECORD_TYPE_ID==ACTIVITY1_ID
        precision = 'ubit12=>double';
        bitsPerAxis = 12;
        bitsPerActivityRecord = NUM_AXES_PER_RECORD*bitsPerAxis;  %size in number of bits (12 bits per acceleration axis)
    elseif RECORD_TYPE_ID == ACTIVITY2_ID
        precision = 'int16=>double';  %
        bitsPerAxis = 16; % now quite accurate in terms of sampling based on the math above, but correct for how it is encoded in the file it seems
        bitsPerActivityRecord = NUM_AXES_PER_RECORD*bitsPerAxis;  %size in number of bits (16 bits per acceleration2 axis - signed short - int16)
    else
        precision = 'uint8';
        bitsPerActivityRecord = 8;  %size in number of bits (16 bits per acceleration2 axis - signed shorts)
    end
    
    SEPARATOR_TAG = 30;
    CHECKSUM_SZ = 1;

    bitsPerByte = 8;
    activityRecordsPerByte = bitsPerByte/bitsPerActivityRecord;

    curRecord = 1;
    axesUBitData = zeros(recordCount,NUM_AXES_PER_RECORD);
    timestamps = zeros(recordCount,1);
    corrupted = false;

    frewind(fid);
    warnings_given = 0;
    
    while ~feof(fid) && curRecord<=recordCount && ~corrupted        
        separator = fread(fid,1,'uint8');
        
        % See reference note re rare cases where a series of 0 values may be
        % found between valid records and can be ignored because the data is
        % not corrupted.
        while ~feof(fid) && separator==0
            separator = fread(fid,1,'uint8');
        end

        if ~feof(fid)
            if separator ~= SEPARATOR_TAG
                warning('Warning separator does not match expected value.  Assume data corruption.');
                corrupted = true;
            else
                recordType = fread(fid,1,'uint8');
                timeStamp = fread(fid,1,'uint32=>double','l');
                payloadSz = fread(fid,1,'uint16','l');
                if payloadSz>1 && recordType ==  RECORD_TYPE_ID                    
                    if recordType == ACTIVITY1_ID
                        packetRecordCount = payloadSz*activityRecordsPerByte;                                            
                        axesUBitData(curRecord:curRecord+packetRecordCount-1,:) = fread(fid,[NUM_AXES_PER_RECORD,packetRecordCount],precision)';
                    elseif recordType == ACTIVITY2_ID
                        packetRecordCount = payloadSz*activityRecordsPerByte;
                        axesUBitData(curRecord:curRecord+packetRecordCount-1,:) = fread(fid,[NUM_AXES_PER_RECORD,packetRecordCount],precision,'l')';
                    else
                        packetRecordCount = 1;
                        if warnings_given==0
                            warning('Unhandled activity type ID: %d', recordType);
                            warnings_given = 1;
                        end                        
                    end
                    timestamps(curRecord:curRecord+packetRecordCount-1) = timeStamp;
                    curRecord = curRecord+packetRecordCount;
                    checksum = fread(fid, CHECKSUM_SZ, 'uint8');
                else
                    % fseek(fid,packetSizeBytes+checksumSizeBytes,0);
                    fseek(fid, payloadSz+CHECKSUM_SZ,"cof");
                end
            end
        end
    end
    curRecord = curRecord -1;  %adjust for the 1 base offset matlab uses.
    if(recordCount~=curRecord)
        fprintf(1,'There is a mismatch between the number of records expected (%d) and the number of records found (%d).\n',recordCount, curRecord);  % \n\tPlease check your data for corruption.\n');
    end
end
