function [records, timestamps] = fgetactigraphrecords(fid, RECORD_TYPE_ID, recordCount)
    narginchk(2,3);

    if nargin<3 || isempty(recordCount)
        recordCount = fgetactigraphrecordcount(fid, RECORD_TYPE_ID);
    end
    
    SEPARATOR_TAG = 30;
    CHECKSUM_SZ = 1;


    if RECORD_TYPE_ID == 6
        precision = 'uint8=>char';
    else
        precision = '*uint8';
    end

    curRecord = 1;
    timestamps = zeros(recordCount,1);
    records = cell(recordCount, 1);

    corrupted = false;

    frewind(fid);
    
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
                timeStamp = fread(fid,1,'uint32=>double');
                payloadSz = fread(fid,1,'uint16','l');
                if recordType == RECORD_TYPE_ID
                    records{curRecord} = fread(fid,[1, payloadSz],precision);
                    timestamps(curRecord) = timeStamp;                
                    checksum = fread(fid, CHECKSUM_SZ, 'uint8');
                    curRecord = curRecord+1;
                else
                    fseek(fid, payloadSz+CHECKSUM_SZ,"cof");
                end
            end
        end
    end
    curRecord = curRecord -1;  %adjust for the 1 base offset matlab uses.
    if(recordCount~=curRecord)
        fprintf(1,'There is a mismatch between the number of records expected and the number of records found.\n\tPlease check your data for corruption.\n');
    end
end