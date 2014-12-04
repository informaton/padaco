function processResults()
baseFeatureTypes = {'mean','mode','rms','std','sum','var'};
signalTypes = {'x','y','z','vecMag'};
valueTypes = {'values','normalizedValues'};
    
if(nargin<1)
    baseFeature = baseFeatureTypes{5};
    baseFeature = 'rms';
    baseFeature = 'mean';
    baseFeature = 'rms';
    curSignal = signalTypes{4};
    filename=sprintf('/Volumes/SeaG 1TB/sampleData/output/features/%s/features.%s.accel.count.%s.txt',baseFeature,baseFeature,curSignal);
    
    %filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
    trimResults = false;
end
    featureStruct = loadAlignedFeatures(filename);
    c = 1;
    curFeature = 'sum';    parameter = [];
%    curFeature = 'peakCount';     parameter = [];
%    curFeature = 'greaterthancount';     parameter = 5;

    loadFeatures = extractLoadShapeFeatures(featureStruct.(valueTypes{c}),curFeature,parameter);
    
    daysofweek = featureStruct.startDaysOfWeek;
    
    if(trimResults)
        trimInd = loadFeatures < prctile(loadFeatures,99);
        features = loadFeatures(trimInd);
        dayofweek = daysofweek(trimInd);
    else
       features =  loadFeatures;
    end
    
    weekendInd = daysofweek==0|daysofweek==6;
    weekdayInd = ~weekendInd;
    % trim?
    M = 30;

    view = {'all','weekdays','weekends'};
    figure('toolbar','none','menubar','none','name',curFeature);
    linecolors = 'bgc';
    for v=1:numel(view)
        curView = view{v};
        switch curView
            case 'all'
                curFeatures = features;
            case 'weekdays'
                curFeatures = features(weekdayInd);
            case 'weekends'
                curFeatures = features(weekendInd);
            otherwise
                disp Bust;
        end
       % curFeatures = curFeatures/sum(curFeatures);
        subplot(4,1,v);
        %trimFeatures = trimFeatures(curFeatures);
        
        %trimmedFeatures = curFeatures;
        % get the updated values
        [Y,M] = hist(curFeatures,M);
        Y = Y/sum(Y);
        %plot it
        width=0.99;
        bar(M,Y,width,'stacked',linecolors(v));
        title(curView);

        if(v>1)
            subplot(4,1,4); hold on;
            
            delta = (M(2)-M(1))*(v-2)/2;            
            bar(M+delta,Y,width/2,'stacked',linecolors(v));

%            delta = (M(2)-M(1))*(v-1)/3;            
%            bar(M+delta,Y,width/3,'stacked',linecolors(v));
        end
        
    end
    
    %     curFeature = 'sumsqr';
%     loadFeatures = extractLoadShapeFeatures(featureStruct.(valueTypes{c}),curFeature);
%     figure;
%     hist(loadFeatures,100);
    
    
end

function trimmedFeatures = trimFeatures(loadFeatures)
    trimmedFeatures = prctile(loadFeatures,0.95);
end