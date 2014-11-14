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
    
    methodDescription = fgetl(fid);
    featureStruct.methodDescription = strrep(strrep(methodDescription,'# Feature:',''),char(9),'');
    startTimes = strrep(fgetl(fid),'#','');
    pattern = '\s+(\d+:\d+)+';
    result = regexp(startTimes,pattern,'tokens');

    startTimes = cell(size(result));
    numCols = numel(startTimes);    

    for c=1:numCols
        startTimes{c} = result{c}{1};
    end
    featureStruct.startTimes = startTimes;
%     urhere = ftell(fid);
%     fseek(fid,urhere,'bof');
    
    scanStr = repmat(' %f',1,numCols);
    
    C = textscan(fid,scanStr,'commentstyle','#','delimiter','\t');
    featureStruct.values = cell2mat(C);
    fclose(fid);



end