function processClusters()
close all;
baseFeatureTypes = {'mean','mode','rms','std','sum','var'};
signalTypes = {'x','y','z','vecMag'};
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
   
end
    featureStruct = loadAlignedFeatures(filename);
    loadShapes = featureStruct.normalizedValues;
    
    daysofweek = featureStruct.startDaysOfWeek;
    daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
    daysofweekOrder = 1:7;
    
    thresholdScale = 1.5;
    minClusters = 40;
    maxClusters = size(loadShapes,1)/2;
    divisionsPerDay = size(loadShapes,2);
    displaySelection = 'adaptivekmeans';

    f=figure('toolbar','none','menubar','none','name',sprintf('Clustering (%s)',baseFeature));
    ylabelstr = sprintf('Count of %s clustering of %s %s activity',displaySelection,processType,curSignal);
    xlabelstr = 'Cluster';
    switch(displaySelection)
        case 'adaptivekmeans'
            [idx, centroids] = adaptiveKmeans(loadShapes,minClusters, maxClusters, thresholdScale);
            numCentroids = size(centroids,1);
            n = histc(idx,1:numCentroids);
            [nsorted,ind] = sort(n);
            bar(nsorted);
            title('Adaptive Clustering Distribution');
            ylabel(ylabelstr);
            xlabel(xlabelstr);

            topN = 5;
            f=figure('toolbar','none','menubar','none','name',sprintf('Top %u Clustering Centroids (%s)',topN,baseFeature));
            sortedCentroids = centroids(ind,:);
            dailyDivisionTicks = 1:8:featureStruct.totalCount;
            
            for t=1:topN
                subplot(topN,1,t);
                plot(sortedCentroids(end-t+1,:));
                title(sprintf('Top Cluster %u (n=%u)',t,nsorted(end-t+1)));
                set(gca,'ylim',[0 0.05],'xtick',dailyDivisionTicks,'xticklabel',featureStruct.startTimes(1:8:end));
            end
            
        otherwise
            disp Oops!;
    end
    
end

function trimmedFeatures = trimFeatures(loadFeatures)
    trimmedFeatures = prctile(loadFeatures,0.95);
end