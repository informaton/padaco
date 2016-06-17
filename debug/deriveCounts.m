%> @brief This script is used to determine how Actigraph counts found in
%> their processed files are derived from the raw sensor readings found in
%> their .raw files.
function [countData, rawData, filter_rawData, filtfilt_rawData, acti_ubit12, rawData_ubit12] = deriveCounts()
    % Load a .raw file within a PAData object.  This ensures that both .raw and
    % count values are read in.
    
    testingPath = '/Users/unknown/Data/GOALS/Temp';
    sqlite_testFile = '704397t00c1_1sec.sql';  % SQLite format 3  : sqlite3 -> .open 704397t00c1_1sec.sql; .tables; select * from settings; .quit;  (ref: https://www.sqlite.org/cli.html)
    csv_testFile = '704397t00c1.csv';
    bin_testFile = 'activity.bin';  %firmware version 2.5.0
    raw_filename = fullfile(testingPath,bin_testFile);
    count_filename = fullfile(testingPath,csv_testFile);
    raw_dataObject = PAData(raw_filename);
    count_dataObject = PAData(count_filename);
    
    %raw - sampled at 40 Hz
    %count - 1 Hz -> though upsampled from file to 40Hz during data object
    %loading.
    fs = raw_dataObject.getSampleRate();  %40;
    
    soi = 'x';
    
    
    firstNonZeroCountValue = find(count_dataObject.accel.count.(soi),1);
    
    
    %examine big spike of activitiy
    soi = 'x';
    firstNonZeroCountValue_At_fs = (firstNonZeroCountValue-1)*fs+1;
    % If FNZCV = 1; then FNCV_At_fs = 1.  If FNZCV = 2, then FNZCV_At_fs = (2-1)*40+1 = 41  q.e.d.
    
    % example conversion
    % Count - Samples   - Derivation
    %   1      1:40       0*40+1:1*40
    %   2     41:80       1*40+1:2*40
    %   n                 (n-1)*40+1:n*40
    
    
    
    %let's start with a value of zero if we can.
    numPreviousSeconds = 15;
    if(firstNonZeroCountValue_At_fs>fs*numPreviousSeconds) % If FNCV = 11, then FNCV_At_Fs = 401;
        firstNonZeroCountValue_At_fs = firstNonZeroCountValue_At_fs-fs*numPreviousSeconds;  % If FNCV_At_Fs = 401-400 = 1;
        firstNonZeroCountValue = firstNonZeroCountValue-numPreviousSeconds;  % then FNCV = 11 - 10 = 1 q.e.d
    end
    
    samplesToCheck = numPreviousSeconds*2;
    
    countRange = firstNonZeroCountValue:firstNonZeroCountValue+samplesToCheck;
    rawRange = firstNonZeroCountValue_At_fs:firstNonZeroCountValue_At_fs+samplesToCheck*fs;
    
    countData = count_dataObject.accel.count.(soi)(countRange);
    rawData =   (raw_dataObject.accel.raw.(soi)(rawRange));
    acti_ubit12 = acti_double2ubit12(rawData);
    rawData_ubit12 = double2ubit12(rawData);
    
%     [filter_rawData, filtfilt_rawData] = acti_iir_filter(rawData,fs);
    
    [filter_rawData, filtfilt_rawData] = acti_fir_filter(rawData,fs);
    
%     [filter_rawData, filtfilt_rawData] = acti_filter(abs(rawData),fs);subplot(2,1,1);plot((conv(((filtfilt_rawData)),ones(1,40))));xlim([1 1200]);subplot(2,1,2);plot(abs(conv(((filtfilt_rawData)),ones(1,40))));xlim([1 1200]);
    x=reshape(filtfilt_rawData(1:samplesToCheck),fs,[]);
    counts = sum(abs(x)); % sum down the columns
    plot(counts);
    


    
%     qsig= quantize(sig, nt);
    
    b_summer = ones(1,fs);
    a_summer = 1;
    
    
    sum_rawData = conv(rawData,b_summer);
    sum_filter_rawData = conv(abs(filter_rawData),b_summer);
    sum_filtfilt_rawData = conv(round(abs(filtfilt_rawData)),b_summer);
    
%     sum_rawData = sum_rawData(1:fs:end);
%     sum_filter_rawData = sum_filter_rawData(1:fs:end);
%     sum_filtfilt_rawData = sum_filtfilt_rawData(1:fs:end);    
%     
    
    close all;
    figure;
    subplot(7,1,1);
    stem(countData);
    xlim([1 numel(countData)]);
%     ylim([0 5]);
    title('count data');
    subplot(7,1,2);
    stem(rawData);
    xlim([1 numel(rawData_ubit12)]);
    title('raw data');
    subplot(7,1,3);
    stem(sum_rawData);
    xlim([1 numel(sum_rawData)]);
    title('sum(raw data)');
    subplot(7,1,4);
    stem(filter_rawData);
    xlim([1 numel(filter_rawData)]);
    title('filter(raw data)');
    subplot(7,1,5);
    stem(sum_filter_rawData);
    xlim([1 numel(sum_filter_rawData)]);
    title('sum(filter(raw data))');
    subplot(7,1,6);
    stem(filtfilt_rawData);
    xlim([1 numel(filtfilt_rawData)]);
    title('filfilt(raw data)');
    subplot(7,1,7);
    stem(sum_filtfilt_rawData);
    xlim([1 numel(sum_filtfilt_rawData)]);
    title('sum(filfilt(raw data))');
    
    figure;
    x=reshape(filtfilt_rawData,fs,[]);
    counts = sum(x); % sum down the columns
    
    %countShortData = dataObject.accel.count.(soi)(countRange(1:fs:end));
    %countLongData = dataObject.accel.count.(soi)(countRange);
    
end


function rawData_ubit12 = double2ubit12(raw_double)
    % Learning point:  The raw data was already packed in 12 bit before
    % converted to double (see PAData loadRawBinActivityFile())
    % Creating a quantizer here should not be adding value, other than
    % returning ourselves back to the original raw ubit12 data.
    num_bits = 12;
    signed = 0;  %original data was not signed..
    word_length = num_bits;
    fraction_length = num_bits-1;  %we have +/-6g dynamic resolution.
    nt = numerictype(signed,word_length,fraction_length);
    
    rawData_ubit12 = quantize(fi(raw_double),nt);
end

% function qsig = quantizer(sig, num_bits)
%     signed = 0;
%     word_length = num_bits;
%     fraction_length = 0;
%     nt = numerictype(signed,word_length,fraction_length);
%     qsig= quantize(sig, nt);
% 
% end


function testSomeFilters
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
    
end