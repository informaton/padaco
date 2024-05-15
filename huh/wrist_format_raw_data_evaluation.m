wrist_data_file = '~/Data/example-2_wrist.gt3x';
binFilename = '~/Data/example-2_wrist/log.bin';
info_file = '~/Data/example-2_wrist/info.txt';

bin_filepath = fileparts(binFilename);
sensorObj = PASensorData();

% Option 1
sensorObj.loadFile(wrist_data_file);

% Option 2
sensorObj.loadPathOfRawBinary(bin_filepath)

% Option 3
sensorObj.loadFile(binFilename);

% Option 4
t = PASensorData.parseInfoTxt(info_file);
recordTypeToGet = 26;
accelerationScale = t.Acceleration_Scale;
[axes_data, datenums]= getActigraphRecordsFromBin(binFilename, recordTypeToGet, accelerationScale, t.Sample_Rate);


% Option 5
fid = fopen(binFilename,'r');
[axes_bit_data, timestamps_unix]= fgetactigraphaxesrecords(binFilename, recordTypeToGet);
% convert bit data to floating point and timestamps from ticks to datenums
fclose(fid);

% Option 6
try
    tag = 6;
    % tag = 21;
    fid = fopen(binFilename,'r');
    [json_data, timestamps_unix]= fgetactigraphrecords(fid, tag);
    % convert bit data to floating point and timestamps from ticks to datenums
    
catch me
    showME(me);
end
fclose(fid);