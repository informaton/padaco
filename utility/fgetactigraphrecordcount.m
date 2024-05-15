function recordCount = fgetactigraphrecordcount(fid, record_type)
    activity1_type_id = 0;  % this is for the three axis of accelarations as y, x, z
    activity2_type_id = 26;  % this is for the three axis of accelarations as x, y, z

    if nargin < 2
        record_type = activity2_type_id;
    end
    frewind(fid);
    recordCount = double(0);
    while ~feof(fid)
        record = fgetactigraphrecord(fid);
        if ~isempty(record)
            recordCount = recordCount + (record.activityType == record_type);
        end
    end
    frewind(fid);
end