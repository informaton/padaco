function featureStruct = loadAlignedFeatures(filename)
if(nargin<1)
    filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
    
end
    [~,fileN, ~] = fileparts(filename);
    [~, remain] = strtok(fileN,'.');    
    
    [method, remain] = strtok(remain,'.');
    featureStruct.method = method;    
    featureStruct.signal.tag = remain(2:end);
    
    [signalGroup, remain] = strtok(remain,'.');
    [signalSource, remain] = strtok(remain,'.');
    signalName = strtok(remain,'.');
    
    
    featureStruct.signal.group = signalGroup;
    featureStruct.signal.source = signalSource;
    featureStruct.signal.name = signalName;
    
    
    fid = fopen(filename,'r');

    featureStruct.methodDescription = strrep(strrep(fgetl(fid),'# Feature:',''),char(9),'');    
    featureStruct.totalCount = str2double(strrep(strrep(fgetl(fid),'# Length:',''),char(9),''));
    
    startTimes = strrep(fgetl(fid),sprintf('# Start Datenum\tStart Day'),'');
    pattern = '\s+(\d+:\d+)+';
    result = regexp(startTimes,pattern,'tokens');

    startTimes = cell(size(result));
    numCols = numel(startTimes);    

    if(numCols~=featureStruct.totalCount)
        fprintf('Warning!  The number of columns listed and the number of columns found in %s do not match.\n',filename);
    end
    for c=1:numCols
        startTimes{c} = result{c}{1};
    end
    
    featureStruct.startTimes = startTimes;
    %     urhere = ftell(fid);
    %     fseek(fid,urhere,'bof');
    
    % +2 because of datenum and start date of the week that precede the
    % time stamps.
    scanStr = repmat(' %f',1,numCols+2);
    
    C = textscan(fid,scanStr,'commentstyle','#','delimiter','\t');
    featureStruct.startDatenums = cell2mat(C(:,1));    
    featureStruct.startDaysOfWeek = cell2mat(C(:,2));
    featureStruct.values = cell2mat(C(:,3:end));
    featureStruct.normalizedValues =  normalizeLoadShapes(featureStruct.values);
    fclose(fid);
end