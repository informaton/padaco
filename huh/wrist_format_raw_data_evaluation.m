wrist_data_file = '~/Data/example-2_wrist.gt3x';
binFilename = '~/Data/example-2_wrist/log.bin';
info_file = '~/Data/example-2_wrist/info.txt';

bin_filepath = fileparts(binFilename);

% Option 1 - load data directly from the .gt3x file
sensorObj = PASensorData();
sensorObj.loadFile(wrist_data_file);   % sensorObj.loadActigraphFile(wrist_data_file) works here as well.
[sensorObj.accel.raw.x(1:10), sensorObj.accel.raw.y(1:10), sensorObj.accel.raw.z(1:10)]
datestr(sensorObj.dateTimeNum(1:10))


% Option 2 - load data from the path containing the uncompressed .gt3x data
sensorObj = PASensorData();
sensorObj.loadPathOfRawBinary(bin_filepath);
datestr(sensorObj.dateTimeNum(1:10))


% Option 3 - load data from the extracted .bin file using loadFile wrapper
sensorObj = PASensorData();
sensorObj.loadFile(binFilename);  % sensorObj.loadActigraphFile(binFilename) works here as well
datestr(sensorObj.dateTimeNum(1:10))


% Option 4 - handle the extraction process directly
t = PASensorData.parseInfoTxt(info_file);
recordTypeToGet = 26;
accelerationScale = t.Acceleration_Scale;
[axes_data, datenums]= getActigraphRecordsFromBin(binFilename, recordTypeToGet, t.Acceleration_Scale, t.Sample_Rate);

axes_data(1:10,:) % first 10 samples of the x, y, z data
datestr(datenums(1:10)) % timestamps of the first 10 samples.  these all match because the timestamps are provided in 1 second blocks, but the sampling rate is higher than this.




% Option 5 - this option is not ready yet because of how the records are
% retrieved which do not take the samling rate into account.  the records
% are packed into one second epochs, but sampled at Sample_Rate.  So there
% are actually Sample_Rate*recordCount number of data entries per axis.
% The above options take this into account, but this option does not; yet.
fid = fopen(binFilename,'r');
[axes_bit_data, timestamps_unix]= fgetactigraphaxesrecords(binFilename, recordTypeToGet);
% convert bit data to floating point and timestamps from ticks to datenums
fclose(fid);
acceleration_scale = 255; % or 341, you will need to check the info.txt file for the correct scaling used for your recording.
axes_data = axes_bit_data/acceleration_scale;
datenums = timestampunix2datenums(timestamps_unix);
