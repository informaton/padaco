% Removed from PAStattool on 3/1/2019 - replaced with toolbar icons
% Functions affected: 
% PAView:   disableWidgets, initWidgets
% padaco:   initializeGUI
% PAStatTool:  initWidgets, hideClusterControls,
%              showClusterControls, initHandles, getPlostSettings
%               mainFigureKeyPressFcn
%   check_holdYAxes:  primaryAxesScalingCallback, checkHoldYAxesCallback
%   check_holdPlots:  primaryAxesNextPlotCallback, showNextClusterCallback,
%                   showPreviousClusterCallback, clearHistogramButtonDownFcn, clusterHistogramPatchButtonDownFcn
%                   scatterPlotCOIButtonDownFcn, scatterplotButtonDownFcn
%   check_showAnalysisFigure:
%               initScatterPlotFigure, shouldShowAnalysisFigure, hideAnalysisFigure
%               getPlotSettings      

% function initWidgets(this, widgetSettings


.... 
    
% bgColor = get(this.handles.panel_clusterPlotControls,'Backgroundcolor');
RGB_MAX = 255;
bgColor = get(this.handles.push_nextCluster,'backgroundcolor');
imgBgColor = bgColor*RGB_MAX;

%    bgColor = [nan, nan, nan];
% bgColor = [0.94,0.94,0.94];
originalImg = imread('arrow-right_16px.png','png','backgroundcolor',bgColor);

%                         set(this.handles.push_nextCluster,'units','pixels');
%                         pos = get(this.handles.push_nextCluster,'position');
%                         originalImg = imresize(originalImg,pos(3:4));

[nRows, nCols, nColors] = size(originalImg);

transparentIndices = false(size(originalImg));  % This is for obtaining logical matrix
for i=1:nColors
    transparentIndices(:,:,i) = originalImg(:,:,i)==imgBgColor(i);
end

% This needs to start with NaNs, otherwise MATLAB
% will convert nan to 0.
transparentImg = nan(size(originalImg));
nextImg = transparentImg;

nextImg(~transparentIndices)=originalImg(~transparentIndices)/RGB_MAX; %normalize back to between 0.0 and 1.0 or NaN
previousImg = fliplr(nextImg);

%setIcon(this.handles.push_nextCluster,'arrow-right_16px.png',imgBgColor);
fgColor = get(0,'FactoryuicontrolForegroundColor');
defaultBackgroundColor = get(0,'FactoryuicontrolBackgroundColor');

set(this.handles.push_nextCluster,'cdata',nextImg,'callback',@this.showNextClusterCallback);
set(this.handles.push_previousCluster,'cdata',previousImg,'callback',@this.showPreviousClusterCallback);
set([this.handles.push_nextCluster,this.handles.push_previousCluster],...
    'string',[],'foregroundcolor',fgColor,...
    'backgroundcolor',defaultBackgroundColor);


set(this.handles.check_showClusterMembership,'callback',@this.checkShowClusterMembershipCallback);
set(this.handles.check_holdYAxes,'value',strcmpi(widgetSettings.primaryAxis_yLimMode,'manual'),'callback',@this.checkHoldYAxesCallback);
set(this.handles.check_holdPlots,'value',strcmpi(widgetSettings.primaryAxis_nextPlot,'add'),'callback',@this.checkHoldPlotsCallback);
set(this.handles.check_showAnalysisFigure,'value',widgetSettings.showAnalysisFigure,'callback',@this.checkShowAnalysisFigureCallback);

% This had been in there and commented out as well 3/1/2019

%                         set(this.handles.menu_clusterStartTime,'userdata',[],'string',{'Start times'},'value',1);
%                         set(this.handles.menu_clusterStopTime,'userdata',[],'string',{'Stop times'},'value',1);


%                         startStopTimesInDay= 0:1/4:24;
%                         hoursInDayStr = datestr(startStopTimesInDay/24,'HH:MM');
%                         set(this.handles.menu_clusterStartTime,'userdata',startStopTimesInDay(1:end-1),'string',hoursInDayStr(1:end-1,:),'value',widgetSettings.startTimeSelection);
%                         set(this.handles.menu_clusterStopTime,'userdata',startStopTimesInDay(2:end),'string',hoursInDayStr(2:end,:),'value',widgetSettings.stopTimeSelection);



% Turns clustering display on or off
%         % Though I don't think this actually does anything now so have
%         % commented it out - @hyatt 5/11/2017

%         function primaryAxesClusterSummaryContextmenuCallback(this,hObject,~)
%             wasChecked = strcmpi(get(hObject,'checked'),'on');
%             if(wasChecked)
%                 set(hObject,'checked','off');
%                 set(this.handles.text_clusterResultsOverlay,'visible','off');
%             else
%                 set(hObject,'checked','on');
%                 set(this.handles.text_clusterResultsOverlay,'visible','on');
%             end
%         end

% Removed from PACluster.m on 2/25/2019 - replaced with consolidated method
% ======================================================================
%> @brief Performs adaptive k-medoids clustering of input data.
%> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
%> @param settings  Optional struct with following fields [and
%> default values]
%> - @c minClusters [40]  Used to set initial K
%> - @c maxClusters [0.5*N]
%> - @c clusterThreshold [1.5]
%> - @c method  'kmedoids'
%> - @c useDefaultRandomizer boolean to set randomizer seed to default
%> -- @c true Use 'default' for randomizer (rng)
%> -- @c false (default) Do not update randomizer seed (rng).
%> @param performanceAxesH GUI handle to display Calinzki index at each iteration (optional)
%> @note When included, display calinski index at each adaptive k-mediods iteration which is slower.
%> @param textStatusH GUI text handle to display updates at each iteration (optional)
%> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
%> @retval centroids - KxC matrix of cluster centroids.
%> @retval The Calinski index for the returned idx and centroids
%> @retrval Struct of X and Y fields containing the progression of
%> cluster sizes and corresponding Calinski indices obtained for
%> each iteration of k means.
% ======================================================================
function [idx, medoids, performanceIndex, performanceProgression, sumD] = adaptiveKmedoids(this,loadShapes,settings,performanceAxesH,textStatusH)
performanceIndex = [];
X = [];
Y = [];
idx = [];
sumD = [];
% argument checking and validation ....
if(nargin<5)
    textStatusH = -1;
    if(nargin<4)
        performanceAxesH = -1;
        if(nargin<3)
            settings = this.getDefaultParameters();
            settings.maxClusters = size(loadShapes,1)/2;
            settings.clusterMethod = 'kmedoids';
        end
    end
end


if(settings.useDefaultRandomizer)
    rng('default');  % To get same results from run to run...
end

if(ishandle(textStatusH) && ~(strcmpi(get(textStatusH,'type'),'uicontrol') && strcmpi(get(textStatusH,'style'),'text')))
    fprintf(1,'Input graphic handle is of type %s, but ''text'' type is required.  Status measure will be output to the console window.',get(textStatusH,'type'));
    textStatusH = -1;
end

if(ishandle(performanceAxesH) && ~strcmpi(get(performanceAxesH,'type'),'axes'))
    fprintf(1,'Input graphic handle is of type %s, but ''axes'' type is required.  Performance measures will not be shown.',get(performanceAxesH,'type'));
    performanceAxesH = -1;
end

% Make sure we have an axes handle.
if(ishandle(performanceAxesH))
    %performanceAxesH = axes('parent',calinskiFig,'box','on');
    %calinskiLine = line('xdata',nan,'ydata',nan,'parent',performanceAxesH,'linestyle','none','marker','o');
    xlabel(performanceAxesH,'K');
    ylabel(performanceAxesH,sprintf('%s Index',this.performanceCriterion'));
end

K = settings.minClusters;

N = size(loadShapes,1);
firstLoop = true;
if(settings.maxClusters==0 || N == 0)
    performanceProgression.X = X;
    performanceProgression.Y = Y;
    performanceProgression.statusStr = 'Did not converge: empty data set received for clustering';
    medoids = [];
    
else
    % prime loop condition since we don't have a do while ...
    numNotCloseEnough = settings.minClusters;
    
    while(numNotCloseEnough>0 && K<=settings.maxClusters && ~this.getUserCancelled())
        if(~firstLoop)
            if(numNotCloseEnough==1)
                statusStr = sprintf('1 cluster was not close enough.  Setting desired number of clusters to %u.',K);
            else
                statusStr = sprintf('%u clusters were not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);
            end
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end-1:end);statusStr]);
            end
            
        else
            statusStr = sprintf('Initializing desired number of clusters to %u.',K);
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            
        end
        
        tic
        
        if(firstLoop)
            % prime the kmedoids algorithms starting centroids
            % - Turn this off for reproducibility
            if(settings.initClusterWithPermutation)
                medoids = loadShapes(pa_randperm(N,K),:);
                [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'distance',this.distanceMetric);
            else
                [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'distance',this.distanceMetric);
            end
            firstLoop = false;
        else
            [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'distance',this.distanceMetric);
        end
        
        if(ishandle(performanceAxesH))
            if(strcmpi(this.performanceCriterion,'silhouette'))
                performanceIndex  = mean(silhouette(loadShapes,idx,this.distanceMetric));
                
            else
                performanceIndex  = this.getCalinskiHarabaszIndex(idx,medoids,sumD);
            end
            X(end+1)= K;
            Y(end+1)=performanceIndex;
            PACluster.plot(performanceAxesH,X,Y);
            
            %statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);
            statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
            
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end-1:end);statusStr]);
            end
            
            drawnow();
            %plot(calinskiAxes,'xdata',X,'ydata',Y);
            %set(calinskiLine,'xdata',X,'ydata',Y);
            %set(calinkiAxes,'xlim',[min(X)-5,
            %max(X)]+5,[min(Y)-10,max(Y)+10]);
        end
        
        
        removed = sum(isnan(medoids),2)>0;
        numRemoved = sum(removed);
        if(numRemoved>0)
            statusStr = sprintf('%u clusters were dropped during this iteration.',numRemoved);
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            
            medoids(removed,:)=[];
            K = K-numRemoved;
            [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'onlinephase','off','distance',this.distanceMetric);
            
            % We performed another clustering step just now, so
            % show these results.
            if(ishandle(performanceAxesH))
                if(strcmpi(this.performanceCriterion,'silhouette'))
                    performanceIndex  = mean(silhouette(loadShapes,idx,this.distanceMetric));
                    
                else
                    performanceIndex  = this.getCalinskiHarabaszIndex(idx,medoids,sumD);
                end
                X(end+1)= K;
                Y(end+1)=performanceIndex;
                PACluster.plot(performanceAxesH,X,Y);
                
                statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                
                fprintf(1,'%s\n',statusStr);
                if(ishandle(textStatusH))
                    curString = get(textStatusH,'string');
                    set(textStatusH,'string',[curString(end);statusStr]);
                end
                
                drawnow();
                
                %set(calinskiLine,'xdata',X,'ydata',Y);
                %set(calinkiAxes,'xlim',[min(X)-5,
                %max(X)]+5,[min(Y)-10,max(Y)+10]);
            end
        end
        
        toc
        
        point2centroidDistanceIndices = sub2ind(size(pointToClusterDistances),(1:N)',idx);
        distanceToClusters = pointToClusterDistances(point2centroidDistanceIndices);
        sqEuclideanClusters = (sum(medoids.^2,2));
        
        clusterThresholds = settings.clusterThreshold*sqEuclideanClusters;
        notCloseEnoughPoints = distanceToClusters>clusterThresholds(idx);
        notCloseEnoughClusters = unique(idx(notCloseEnoughPoints));
        
        numNotCloseEnough = numel(notCloseEnoughClusters);
        if(numNotCloseEnough>0)
            medoids(notCloseEnoughClusters,:)=[];
            for k=1:numNotCloseEnough
                curClusterIndex = notCloseEnoughClusters(k);
                clusteredLoadShapes = loadShapes(idx==curClusterIndex,:);
                numClusteredLoadShapes = size(clusteredLoadShapes,1);
                if(numClusteredLoadShapes>1)
                    try
                        [~,splitClusters] = kmedoids(clusteredLoadShapes,2,'distance',this.distanceMetric);
                        
                    catch me
                        showME(me);
                    end
                    medoids = [medoids;splitClusters];
                else
                    if(numClusteredLoadShapes~=1)
                        echo(numClusteredLoadShapes); %houston, we have a problem.
                    end
                    numNotCloseEnough = numNotCloseEnough-1;
                    medoids = [medoids;clusteredLoadShapes];
                end
            end
            
            % reset cluster centers now / batch update
            K = K+numNotCloseEnough;
            [~, medoids] = kmedoids(loadShapes,K,'Start',medoids,'onlinephase','off','distance',this.distanceMetric);
        end
    end  % end adaptive while loop
    
    if(numNotCloseEnough~=0 && ~this.getUserCancelled())
        statusStr = sprintf('Failed to converge using a maximum limit of %u clusters.',settings.maxClusters);
        fprintf(1,'%s\n',statusStr);
        if(ishandle(textStatusH))
            curString = get(textStatusH,'string');
            set(textStatusH,'string',[curString(end);statusStr]);
            drawnow();
        end
        
        [performanceIndex, X, Y, idx, medoids] = deal([]);
    else
        if(this.getUserCancelled())
            statusStr = sprintf('User cancelled - completing final clustering operation ...');
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            [idx, medoids, sumD, pointToClusterDistances] = kmedoids(loadShapes,K,'Start',medoids,'distance',this.distanceMetric);
        end
        % This may only pertain to when the user cancelled.
        % Not sure if it is needed otherwise...
        if(ishandle(performanceAxesH))
            if(strcmpi(this.performanceCriterion,'silhouette'))
                performanceIndex  = mean(silhouette(loadShapes,idx));
                
            else
                performanceIndex  = this.getCalinskiHarabaszIndex(idx,medoids,sumD);
            end
            X(end+1)= K;
            Y(end+1)=performanceIndex;
            PACluster.plot(performanceAxesH,X,Y);
            
            statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
            
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            
            drawnow();
            %set(calinskiLine,'xdata',X,'ydata',Y);
            %set(calinkiAxes,'xlim',[min(X)-5,
            %max(X)]+5,[min(Y)-10,max(Y)+10]);
        end
        if(strcmpi(this.performanceCriterion,'silhouette'))
            fmtStr = '%0.4f';
        else
            fmtStr = '%0.2f';
        end
        
        if(this.getUserCancelled())
            statusStr = sprintf(['User cancelled with final cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
        else
            statusStr = sprintf(['Converged with a cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
        end
        fprintf(1,'%s\n',statusStr);
        if(ishandle(textStatusH))
            curString = get(textStatusH,'string');
            set(textStatusH,'string',[curString(end);statusStr]);
        end
    end
    performanceProgression.X = X;
    performanceProgression.Y = Y;
    performanceProgression.statusStr = statusStr;
    performanceProgression.criterion = sprintf('%s Index',sentencecase(this.performanceCriterion));
    
end
end

% ======================================================================
%> @brief Performs adaptive k-means clustering of input data.
%> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
%> @param settings  Optional struct with following fields [and
%> default values]
%> - @c minClusters [40]  Used to set initial K
%> - @c maxClusters [0.5*N]
%> - @c clusterThreshold [1.5]
%> - @c method  'kmeans'
%> - @c useDefaultRandomizer (boolean) Set randomizer seed to default
%> -- @c true Use 'default' for randomizer (rng)
%> -- @c false (default) Do not update randomizer seed (rng).
%> @param performanceAxesH GUI handle to display Calinzki index at each iteration (optional)
%> @note When included, display calinski index at each adaptive k-mediods iteration which is slower.
%> @param textStatusH GUI text handle to display updates at each iteration (optional)
%> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
%> @retval centroids - KxC matrix of cluster centroids.
%> @retval The Calinski index for the returned idx and centroids
%> @retrval Struct of X and Y fields containing the progression of
%> cluster sizes and corresponding Calinski indices obtained for
%> each iteration of k means.
% ======================================================================
function [idx, centroids, performanceIndex, performanceProgression, sumD] = adaptiveKmeans(this,loadShapes,settings,performanceAxesH,textStatusH)
performanceIndex = [];
X = [];
Y = [];
idx = [];
sumD = [];
% argument checking and validation ....
if(nargin<5)
    textStatusH = -1;
    if(nargin<4)
        performanceAxesH = -1;
        if(nargin<3)
            settings = this.getDefaultParameters();
            settings.maxClusters = size(loadShapes,1)/2;
            settings.clusterMethod = 'kmeans';
        end
    end
end


if(settings.useDefaultRandomizer)
    rng('default');  % To get same results from run to run...
end

if(ishandle(textStatusH) && ~(strcmpi(get(textStatusH,'type'),'uicontrol') && strcmpi(get(textStatusH,'style'),'text')))
    fprintf(1,'Input graphic handle is of type %s, but ''text'' type is required.  Status measure will be output to the console window.',get(textStatusH,'type'));
    textStatusH = -1;
end

if(ishandle(performanceAxesH) && ~strcmpi(get(performanceAxesH,'type'),'axes'))
    fprintf(1,'Input graphic handle is of type %s, but ''axes'' type is required.  Performance measures will not be shown.',get(performanceAxesH,'type'));
    performanceAxesH = -1;
end

% Make sure we have an axes handle.
if(ishandle(performanceAxesH))
    %performanceAxesH = axes('parent',calinskiFig,'box','on');
    %calinskiLine = line('xdata',nan,'ydata',nan,'parent',performanceAxesH,'linestyle','none','marker','o');
    xlabel(performanceAxesH,'K');
    ylabel(performanceAxesH,sprintf('%s Index',this.performanceCriterion));
end

K = settings.minClusters;

N = size(loadShapes,1);
firstLoop = true;
if(settings.maxClusters==0 || N == 0)
    performanceProgression.X = X;
    performanceProgression.Y = Y;
    performanceProgression.statusStr = 'Did not converge: empty data set received for clustering';
    centroids = [];
    
else
    % prime loop condition since we don't have a do while ...
    numNotCloseEnough = settings.minClusters;
    
    while(numNotCloseEnough>0 && K<=settings.maxClusters && ~this.getUserCancelled())
        if(~firstLoop)
            if(numNotCloseEnough==1)
                statusStr = sprintf('1 cluster was not close enough.  Setting desired number of clusters to %u.',K);
            else
                statusStr = sprintf('%u clusters were not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);
            end
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end-1:end);statusStr]);
            end
            
        else
            statusStr = sprintf('Initializing desired number of clusters to %u.',K);
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            
        end
        
        tic
        %     IDX = kmeans(X,K) returns an N-by-1 vector IDX containing the cluster
        %     indices of each point -> the loadshapeMap
        %
        %     [IDX, C] = kmeans(X, K) returns the K cluster centroid locations in
        %     the K-by-P matrix C.
        %
        %     [IDX, C, SUMD] = kmeans(X, K) returns the within-cluster sums of
        %     point-to-centroid distances in the 1-by-K vector sumD.
        %
        %     [IDX, C, SUMD, D] = kmeans(X, K) returns distances from each point
        %     to every centroid in the N-by-K matrix D.
        
        
        if(firstLoop)
            % prime the kmeans algorithms starting centroids
            % Can be a problem when we are going to start with repeat
            % clusters.
            if(settings.initClusterWithPermutation)
                centroids = loadShapes(pa_randperm(N,K),:);
                [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','distance',this.distanceMetric);
            else
                [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K);
            end
            firstLoop = false;
            
        else
            [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','distance',this.distanceMetric);
        end
        if(ishandle(performanceAxesH))
            if(strcmpi(this.performanceCriterion,'silhouette'))
                performanceIndex  = mean(silhouette(loadShapes,idx));
                
            else
                performanceIndex  = this.getCalinskiHarabaszIndex(idx,centroids,sumD);
            end
            X(end+1)= K;
            Y(end+1)=performanceIndex;
            PACluster.plot(performanceAxesH,X,Y);
            
            statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
            
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end-1:end);statusStr]);
            end
            
            drawnow();
            %plot(calinskiAxes,'xdata',X,'ydata',Y);
            %set(calinskiLine,'xdata',X,'ydata',Y);
            %set(calinkiAxes,'xlim',[min(X)-5,
            %max(X)]+5,[min(Y)-10,max(Y)+10]);
        end
        
        
        removed = sum(isnan(centroids),2)>0;
        numRemoved = sum(removed);
        if(numRemoved>0)
            statusStr = sprintf('%u clusters were dropped during this iteration.',numRemoved);
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            
            centroids(removed,:)=[];
            K = K-numRemoved;
            [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off','distance',this.distanceMetric);
            
            if(ishandle(performanceAxesH))
                if(strcmpi(this.performanceCriterion,'silhouette'))
                    performanceIndex  = mean(silhouette(loadShapes,idx));
                    
                else
                    performanceIndex  = this.getCalinskiHarabaszIndex(idx,centroids,sumD);
                end
                X(end+1)= K;
                Y(end+1)=performanceIndex;
                PACluster.plot(performanceAxesH,X,Y);
                
                statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
                
                fprintf(1,'%s\n',statusStr);
                if(ishandle(textStatusH))
                    curString = get(textStatusH,'string');
                    set(textStatusH,'string',[curString(end);statusStr]);
                end
                
                drawnow();
                
                %set(calinskiLine,'xdata',X,'ydata',Y);
                %set(calinkiAxes,'xlim',[min(X)-5,
                %max(X)]+5,[min(Y)-10,max(Y)+10]);
            end
        end
        
        toc
        
        point2centroidDistanceIndices = sub2ind(size(pointToClusterDistances),(1:N)',idx);
        distanceToClusters = pointToClusterDistances(point2centroidDistanceIndices);
        sqEuclideanClusters = (sum(centroids.^2,2));
        
        clusterThresholds = settings.clusterThreshold*sqEuclideanClusters;
        notCloseEnoughPoints = distanceToClusters>clusterThresholds(idx);
        notCloseEnoughClusters = unique(idx(notCloseEnoughPoints));
        
        numNotCloseEnough = numel(notCloseEnoughClusters);
        if(numNotCloseEnough>0)
            centroids(notCloseEnoughClusters,:)=[];
            for k=1:numNotCloseEnough
                curClusterIndex = notCloseEnoughClusters(k);
                clusteredLoadShapes = loadShapes(idx==curClusterIndex,:);
                numClusteredLoadShapes = size(clusteredLoadShapes,1);
                if(numClusteredLoadShapes>1)
                    try
                        [~,splitClusters] = kmeans(clusteredLoadShapes,2,'EmptyAction','drop','distance',this.distanceMetric);
                        
                    catch me
                        showME(me);
                    end
                    centroids = [centroids;splitClusters];
                else
                    if(numClusteredLoadShapes~=1)
                        echo(numClusteredLoadShapes); %houston, we have a problem.
                    end
                    numNotCloseEnough = numNotCloseEnough-1;
                    centroids = [centroids;clusteredLoadShapes];
                end
                % for speed
                %[~,centroids(curRow:curRow+1,:)] = kmeans(clusteredLoadShapes,2,'distance',this.distanceMetric);
                %curRow = curRow+2;
            end
            
            % reset cluster centers now / batch update
            K = K+numNotCloseEnough;
            [~, centroids] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off','distance',this.distanceMetric);
        end
    end
    
    
    if(numNotCloseEnough~=0 && ~this.getUserCancelled())
        statusStr = sprintf('Failed to converge using a maximum limit of %u clusters.',settings.maxClusters);
        fprintf(1,'%s\n',statusStr);
        if(ishandle(textStatusH))
            curString = get(textStatusH,'string');
            set(textStatusH,'string',[curString(end);statusStr]);
            drawnow();
        end
        
        % No partial credit
        [performanceIndex, X, Y, idx, centroids] = deal([]);
        
    else
        
        if(this.getUserCancelled())
            statusStr = sprintf('User cancelled - completing final clustering operation ...');
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off','distance',this.distanceMetric);
        end
        if(ishandle(performanceAxesH))
            % getPerformance
            if(strcmpi(this.performanceCriterion,'silhouette'))
                performanceIndex  = mean(silhouette(loadShapes,idx));
            else
                performanceIndex  = this.getCalinskiHarabaszIndex(idx,centroids,sumD);
            end
            X(end+1)= K;
            Y(end+1)=performanceIndex;
            PACluster.plot(performanceAxesH,X,Y);
            
            statusStr = sprintf('%s index = %0.2f for K = %u clusters',this.performanceCriterion,performanceIndex,K);
            
            fprintf(1,'%s\n',statusStr);
            if(ishandle(textStatusH))
                curString = get(textStatusH,'string');
                set(textStatusH,'string',[curString(end);statusStr]);
            end
            
            drawnow();
            
            %set(calinskiLine,'xdata',X,'ydata',Y);
            %set(calinkiAxes,'xlim',[min(X)-5,
            %max(X)]+5,[min(Y)-10,max(Y)+10]);
            
        end
        
        if(strcmpi(this.performanceCriterion,'silhouette'))
            fmtStr = '%0.4f';
        else
            fmtStr = '%0.2f';
        end
        if(this.getUserCancelled())
            statusStr = sprintf(['User cancelled with final cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
        else
            statusStr = sprintf(['Converged with a cluster size of %u.  %s index = ',fmtStr,'  '],K,this.performanceCriterion,performanceIndex);
        end
        fprintf(1,'%s\n',statusStr);
        if(ishandle(textStatusH))
            curString = get(textStatusH,'string');
            set(textStatusH,'string',[curString(end);statusStr]);
        end
    end
    
    
    performanceProgression.X = X;
    performanceProgression.Y = Y;
    performanceProgression.statusStr = statusStr;
    performanceProgression.criterion = sprintf('%s Index',sentencecase(this.performanceCriterion));
    
    
end
end


% Removed from PAData.m on 8/19/2015

% --------------------------------------------------------------------
%> @brief Calculates usage states from @b classifyUsageState method
%> and returns it as a matrix of elapsed time aligned vectors.
%> @param obj Instance of PAData
%> @param elapsedStartHour Elapsed hour (starting from 00:00 for new
%> day) to begin aligning feature vectors.
%> @param intervalDurationHours number of hours between
%> consecutively aligned feature vectors.
%> @note For example if elapsedStartHour is 1 and intervalDurationHours is 24, then alignedFeatureVecs will
%> start at 01:00 of each day (and last for 24 hours a piece).
%> @retval alignedUsageStates NxM matrix where each row is the mode usage state
%> occuring in the alignment region according to elapsed start time and
%> interval duration in hours.  Consecutive rows are vector values in order of the section they are calculated from (i.e. the columns).
%> @retval alignedStartDateVecs Nx6 matrix of datevec values whose
%> rows correspond to the start datevec of the corresponding row of alignedFeatureVecs.
% --------------------------------------------------------------------
% function [alignedUsageStates, alignedStartDateVecs] = getAlignedUsageStates(obj,elapsedStartHour, intervalDurationHours)
%     [usageVec, ~,~] = classifyUsageState(obj);
%     currentNumFrames = obj.getFrameCount();
%     if(currentNumFrames~=obj.numFrames)
%         
%         [frameDurMinutes, frameDurHours ] = obj.getFrameDuration();
%         frameDurSeconds = frameDurMinutes*60+frameDurHours*60*60;
%         obj.numFrames = currentNumFrames;
%         frameableSamples = obj.numFrames*frameDurSeconds*obj.getSampleRate();
%         obj.frames =  reshape(usageVec(1:frameableSamples),[],obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
%         
%         obj.features = [];
%         dateNumIndices = 1:size(obj.frames,1):frameableSamples;
%         
%         %take the first part
%         obj.startDatenums = obj.dateTimeNum(dateNumIndices(1:end));
%     end
%     
%     
%     % get frame duration
%     frameDurationVec = [0 0 0 obj.frameDurHour obj.frameDurMin 0];
%     
%     % find the first Start Time
%     startDateVecs = datevec(obj.startDatenums);
%     elapsedStartHours = startDateVecs*[0; 0; 0; 1; 1/60; 1/3600];
%     startIndex = find(elapsedStartHours==elapsedStartHour,1,'first');
%     
%     startDateVec = startDateVecs(startIndex,:);
%     stopDateVecs = startDateVecs+repmat(frameDurationVec,size(startDateVecs,1),1);
%     lastStopDateVec = stopDateVecs(end,:);
%     
%     % A convoluted processes - need to convert datevecs back to
%     % datenum to handle switching across months.
%     remainingDurationHours = datevec(datenum(lastStopDateVec)-datenum(startDateVec))*[0; 0; 24; 1; 1/60; 1/3600];
%     
%     numIntervals = floor(remainingDurationHours/intervalDurationHours);
%     
%     intervalStartDateVecs = repmat(startDateVec,numIntervals,1)+(0:numIntervals-1)'*[0, 0, 0, intervalDurationHours, 0, 0];
%     alignedStartDateVecs = intervalStartDateVecs;
%     durationDateVec = [0 0 0 numIntervals*intervalDurationHours 0 0];
%     stopIndex = find(datenum(stopDateVecs)==datenum(startDateVec+durationDateVec),1,'first');
%     
%     
%     
%     % reshape the result and return as alignedFeatureVec
%     
%     clippedFeatureVecs = usageVec(startIndex:stopIndex);
%     alignedUsageStates = reshape(clippedFeatureVecs,[],numIntervals)';
%     
% end


% Removed from PAView.m  

% % --------------------------------------------------------------------
% %> @brief Initialize the line handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of line properties corresponding to the
% %> fields of the linehandle instance variable.
% %> If empty ([]) then default PAData.getDummyDisplayStruct is used.
% % --------------------------------------------------------------------
% function initLineHandles(obj,lineProps)
% 
% if(nargin<2 || isempty(lineProps))
%     lineProps = PAData.getDummyDisplayStruct();
% end
% 
% obj.recurseHandleSetter(obj.linehandle, lineProps);
% obj.recurseHandleSetter(obj.referencelinehandle, lineProps);
% 
% 
% end
% 
% % --------------------------------------------------------------------
% %> @brief Initialize the label handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of label properties corresponding to the
% %> fields of the labelhandle instance variable.
% % --------------------------------------------------------------------
% function initLabelHandles(obj,labelProps)
% obj.recurseHandleSetter(obj.labelhandle, labelProps);
% end



% % --------------------------------------------------------------------
% %> @brief Restores the view to ready state (mouse becomes the default pointer).
% %> @param obj Instance of PAView
% % --------------------------------------------------------------------
% function popout_axes(~, ~, axes_h)
% % hObject    handle to context_menu_pop_out (see GCBO)
% % eventdata  reserved - to be defined in a future version of MATLAB
% % handles    structure with handles and user data (see GUIDATA)
% fig = figure;
% copyobj(axes_h,fig); %or get parent of hObject's parent
% end