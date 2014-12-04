function processProgressions()
baseFeatureTypes = {'mean','mode','rms','std','sum','var'};
signalTypes = {'x','y','z','vecMag'};
valueTypes = {'values','normalizedValues'};
processedTypes = {'raw','count'};    
if(nargin<1)
    baseFeature = baseFeatureTypes{5};
    baseFeature = 'rms';
    baseFeature = 'sum';
    baseFeature = 'mean';
%     baseFeature = 'var';
%     baseFeature = 'std';
    
    curSignal = signalTypes{4};
    processType = processedTypes{2};  % = 'count'
    filename=sprintf('/Volumes/SeaG 1TB/sampleData/output/features/%s/features.%s.accel.%s.%s.txt',baseFeature,baseFeature,processType,curSignal);
    
    %filename='/Volumes/SeaG 1TB/sampleData/output/features/mean/features.mean.accel.count.vecMag.txt';
    trimResults = false;
end
    featureStruct = loadAlignedFeatures(filename);
    c = 1;
    curFeature = 'sum';    parameter = [];
%    curFeature = 'peakCount';     parameter = [];
%    curFeature = 'greaterthancount';     parameter = 5;

%    loadFeatures = extractLoadShapeFeatures(featureStruct.(valueTypes{c}),curFeature,parameter);
    
    loadFeatures = featureStruct.(valueTypes{c});
    daysofweek = featureStruct.startDaysOfWeek;
    daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
    daysofweekOrder = 1:7;
    if(trimResults)
        trimInd = loadFeatures < prctile(loadFeatures,99);
        features = loadFeatures(trimInd);
        daysofweek = daysofweek(trimInd);
    else
       features =  loadFeatures;
    end
    divisionsPerDay = size(loadFeatures,2);
    displaySelection = 'heatmap';
%     displaySelection = 'morningheatmap';
    
    displaySelection = 'rolling';
%     displaySelection = 'morningrolling';
%    displaySelection = 'dailytally';
%    displaySelection = 'dailyaverage';

    f=figure('toolbar','none','menubar','none','name',sprintf('Progression (%s)',baseFeature));
    colormap(f,'jet');
    numShades = 1000;
    reds = linspace(0,1,numShades)';
    greens = linspace(0,0.8,numShades)';
    blues = linspace(0,0.2,numShades)';
    intensity = [reds,greens,blues];
    grays = repmat(0:numShades,3,1)'/numShades;
    inverted = flipud(grays);
    colormap(f,intensity);
    colormap(f,grays);
    colormap(f,inverted);
    ylabelstr = sprintf('%s of %s %s activity',baseFeature,processType,curSignal);
    xlabelstr = 'Days of Week';
    switch(displaySelection)
        case 'dailyaverage'
            imageMap = nan(7,1);
            for dayofweek=0:6
                dayofweekIndex = daysofweekOrder(dayofweek+1);
                numSubjects = sum(dayofweek==daysofweek);
                if(numSubjects==0)
                    imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));
                else
                    imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1))/numSubjects;                 
                end
                daysofweekStr{dayofweekIndex} = sprintf('%s\n(n=%u)',daysofweekStr{dayofweekIndex},numSubjects);
                    
            end
            bar(imageMap);
            title('Average Daily Tallies');
            weekdayticks = linspace(1,7,7);

        case 'dailytally'
            imageMap = nan(7,1);
            for dayofweek=0:6
               imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));               
            end
            bar(imageMap);
            title('Total Daily Tallies');
            weekdayticks = linspace(1,7,7);

        case 'morningheatmap'  %note: I use 24 to represent the first 6 hours of the morning (24 x 15 minute blocks = 6 hours)
            imageMap = nan(7,24);
            for dayofweek=0:6                
                imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,1:24),1);
                numSubjects = sum(dayofweek==daysofweek);
                if(numSubjects~=0)
                    imageMap(dayofweek+1,:) = imageMap(dayofweek+1,:)/numSubjects;
                end
            end
            
            imageMap=imageMap/max(imageMap(:));
            imageMap = round(imageMap*numShades);
            imagesc(imageMap');
            weekdayticks = 1:1:7; %linspace(0,6,7);
            dailyDivisionTicks = 1:2:24;
            set(gca,'ytick',dailyDivisionTicks,'yticklabel',featureStruct.startTimes(1:2:24));
            title('Heat map');        
        case 'heatmap'
            imageMap = nan(7,size(features,2));
            for dayofweek=0:6                
                imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
                numSubjects = sum(dayofweek==daysofweek);
                if(numSubjects~=0)
                    imageMap(dayofweek+1,:) = imageMap(dayofweek+1,:)/numSubjects;
                end
            end
            
            imageMap=imageMap/max(imageMap(:));
            imageMap = round(imageMap*numShades);
            imagesc(imageMap');
            weekdayticks = 1:1:7; %linspace(0,6,7);
            dailyDivisionTicks = 1:8:featureStruct.totalCount;
            set(gca,'ytick',dailyDivisionTicks,'yticklabel',featureStruct.startTimes(1:8:end));
            title('Heat map');
        case 'rolling'
            imageMap = nan(7,size(features,2));
            for dayofweek=0:6
               imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
            end
%            imageMap=imageMap/max(imageMap(:));
            rollingMap = imageMap';            
            plot(rollingMap(:));
            title('Rolling Map');
            weekdayticks = linspace(0,divisionsPerDay*6,7);
            set(gca,'ygrid','on');
        case 'morningrolling'
            imageMap = nan(7,24);
            for dayofweek=0:6
               imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,1:24),1);
            end
%            imageMap=imageMap/max(imageMap(:));
            rollingMap = imageMap';            
            plot(rollingMap(:));
            title('Morning Rolling Map (00:00-06:00AM daily)');
            weekdayticks = linspace(0,24*6,7);
            set(gca,'ygrid','on');
            
        case 'quantile'
            
        otherwise
            disp Oops!;
    end
    ylabel(ylabelstr);
    xlabel(xlabelstr);
    set(gca,'xtick',weekdayticks,'xticklabel',daysofweekStr,'xgrid','on');
    
end

function trimmedFeatures = trimFeatures(loadFeatures)
    trimmedFeatures = prctile(loadFeatures,0.95);
end