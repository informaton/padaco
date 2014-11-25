function processResults()
if(nargin<1)
    filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
    trimResults = false;
end
    featureStruct = loadAlignedFeatures(filename);
    valueTypes = {'values','normalizedValues'};
    c = 1;
    curFeature = 'sum';
    curFeature = 'peakCount';
    loadFeatures = extractLoadShapeFeatures(featureStruct.(valueTypes{c}),curFeature);
    
    
    


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
    M = 20;

    view = {'all','weekdays','weekends'};
    figure('toolbar','none','menubar','none','name',curFeature);
    title('hello world');
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
        subplot(3,1,v);
        %trimFeatures = trimFeatures(curFeatures);
        
        %trimmedFeatures = curFeatures;
        % get the updated values
        [~,M] = hist(curFeatures,M);
        
        %plot it
        hist(curFeatures,M);
        title(curView);
        
    end

    
%     curFeature = 'sumsqr';
%     loadFeatures = extractLoadShapeFeatures(featureStruct.(valueTypes{c}),curFeature);
%     figure;
%     hist(loadFeatures,100);
    
    
end

function trimmedFeatures = trimFeatures(loadFeatures)
    trimmedFeatures = prctile(loadFeatures,0.95);
end