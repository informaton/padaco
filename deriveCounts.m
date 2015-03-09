%> @brief This script is used to determine how Actigraph counts found in
%> their processed files are derived from the raw sensor readings found in
%> their .raw files.

% Load a .raw file within a PAData object.  This ensures that both .raw and
% count values are read in.

testingFilename = '/Users/hyatt4/Google Drive/work/Stanford - Pediatrics/sampledata/female child.raw';

dataObject = PAData(testingFilename);

%raw - sampled at 40 Hz
%count - 1 Hz -> though upsampled from file to 40Hz during data object
%loading.
fs = 40;

soi = 'x';

numValuesToCheck = 75;
firstNonZeroValue = find(dataObject.accel.count.(soi),1);


%examine big spike of activitiy
soi = 'x';
firstNonZeroValue = 50279*fs+1;
%let's start with a value of zero if we can.
if(firstNonZeroValue>fs)
    firstNonZeroValue = firstNonZeroValue-fs*50;
end
% example conversion
% Count - Samples   - Derivation
%   1      1:40       0*40+1:1*40
%   2     41:80       1*40+1:2*40
%   n                 (n-1)*40+1:n*40
countRange = (0:numValuesToCheck*fs-1)+firstNonZeroValue;
rawRange = countRange;
%rawRange = (countRange(1)-1)*fs+1:countRange(end)*fs;


countShortData = dataObject.accel.count.(soi)(countRange(1:fs:end));
countLongData = dataObject.accel.count.(soi)(countRange);

rawData = dataObject.accel.raw.(soi)(rawRange);

% Now lets make some filters
fc_low_Hz = 1;   % fs/10;  %1 is better than 4 and also 2
fc_high_Hz = 10; % fs - fs/10;
N = 100;
Wn = [fc_low_Hz, fc_high_Hz]/fs;
B = ones(1,N,1);

B = fir1(N,Wn,'bandpass');
A = 1;
filtData = abs(filtfilt(B,A,(rawData(1:end))));

nColumns = 24;
rowData = filtData;
% rowData = rawData;
%lets just look at the first ten rows shall we.

columnFilterData = abs(reshape(filtData(1:nColumns*fs),fs,[]));
columnRawData = reshape(rawData(1:nColumns*fs),fs,[]);
columnCountData = countData(1:nColumns)';
%[columnFilterData;nan(1,nColumns);sum((columnRawData));nan(1,nColumns);sum(columnFilterData);nan(1,nColumns);columnCountData]
[sum(abs(columnRawData));nan(1,nColumns);sum(columnFilterData);nan(1,nColumns);columnCountData]



%using filter and a scaler - this one works well!
x=1:numel(rawData);SumRawFilterN = 10;SumFilterN = fs*1; sumFiltData = SumFilterN/100*(filtfilt(ones(SumFilterN,1),1,(filtData)));sumRawData = filtfilt(ones(SumRawFilterN,1),1,abs(rawData));close all;plot(x,rawData(x),'g',x,countLongData(x),'b',x,abs(filtData(x)),'r',x,sumFiltData(x),'k');


x=1:numel(rawData);SumRawFilterN = 10;SumFilterN = fs*0.5; sumFiltData = fs/SumFilterN*(filtfilt(ones(SumFilterN,1),1,(filtData)));sumRawData = filtfilt(ones(SumRawFilterN,1),1,abs(rawData));close all;plot(x,rawData(x),'g',x,countLongData(x),'b',x,abs(filtData(x)),'r',x,sumFiltData(x),'k');









%  too much on display here
x=1:numel(rawData);SumRawFilterN = 10;SumFilterN = 40*0.5; sumFiltData = filtfilt(ones(SumFilterN,1),1,abs(filtData));sumRawData = filtfilt(ones(SumRawFilterN,1),1,abs(rawData));close all;plot(x,rawData(x)*100,'g',x,countLongData(x),'b',x,abs(filtData(x))*100,'r',x,sumFiltData(x),'k',x,sumRawData(x),'y');


% command line helper
%'x' data
soi='y';filtData = filtfilt(B,1,dataObject.accel.raw.(soi));x=1:60*40;close all;plot(x,dataObject.accel.raw.(soi)(x),'r',x,dataObject.accel.count.(soi)(x)/100,'b',x,filtData(x),'g')

% working 
fc_low_Hz = 3;   % fs/10;
fc_high_Hz = 33; % fs - fs/10;
N = 100;
Wn = [fc_low_Hz, fc_high_Hz]/fs;
A=1;sumFilterN=100*0.4;threshold = 0.1;soi='z';B = fir1(N,Wn/2,'bandpass');filtData = filtfilt(B,A,dataObject.accel.raw.(soi));sumFiltData = filter(ones(sumFilterN,1),1,abs(filtData)>threshold);x=1:60*40;close all;plot(x,dataObject.accel.raw.(soi)(x),'g',x,dataObject.accel.count.(soi)(x),'b',x,abs(filtData(x)),'r',x,sumFiltData(x),'k')
A=1;sumFilterN=100*0.4;threshold = 0.1;soi='z';B = fir1(N,Wn/2,'bandpass');filtData = filtfilt(B,A,dataObject.accel.raw.(soi));sumFiltData = filter(ones(sumFilterN,1),1,abs(filtData)>threshold);x=1:60*40;close all;plot(x,dataObject.accel.raw.(soi)(x),'g',x,dataObject.accel.count.(soi)(x),'b',x,abs(filtData(x)),'r',x,sumFiltData(x),'k')

% working better for z
fc_low_Hz = 3;   % fs/10;
fc_high_Hz = 33; % fs - fs/10;
N = 100;
Wn = [fc_low_Hz, fc_high_Hz]/fs;
sumFilterN=N*1.25;threshold = fs/N/10;soi='z';B = fir1(N,Wn/2,'bandpass');filtData = filtfilt(B,1,dataObject.accel.raw.(soi));sumFiltData = filter(ones(sumFilterN,1),1,abs(filtData)>threshold);x=1:60*40;close all;plot(x,dataObject.accel.raw.(soi)(x),'g',x,dataObject.accel.count.(soi)(x),'b',x,abs(filtData(x)),'r',x,sumFiltData(x),'k')

% closer to success here -----version 1
fc_low_Hz = 2;   % fs/10;
fc_high_Hz = 15; % fs - fs/10;
N = 100;
Wn = [fc_low_Hz, fc_high_Hz]/fs;
soi='x';B = fir1(N,Wn/2,'bandpass');filtData = filtfilt(B,1,dataObject.accel.raw.(soi));sumFiltData = filter(ones(40,1),1,abs(filtData)>1/fs);x=1:60*40;close all;plot(x,dataObject.accel.raw.(soi)(x),'g',x,dataObject.accel.count.(soi)(x),'b',x,abs(filtData(x)),'r',x,sumFiltData(x),'k')