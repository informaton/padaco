% ======================================================================
%> @file PACentroid.cpp
%> @brief Class for clustering results data produced via padaco's batch
%> processing.
% ======================================================================
classdef PACentroid < handle
    
    properties(Access=private)
        %> Struct with cluster calculation settings.  Fields include
        %> - @c minClusters
        %> - @c maxClusters
        %> - @c thresholdScale        
        settings;
        
        %> NxM array of N profiles of length M (M is the centroid
        %> dimensionality)
        loadShapes;
        
        %> Nx1 vector of centroid index for loadShape profile associated with its row.
        load2centroidMap;
        
        %> CxM array of C centroids of size M.
        centroidShapes;
        
        %> Sorted distribution of centroid shapes by frequency of children load shape members.
        %> (Cx1 vector - where is C is the number centroids)
        histogram;
        
        %> Nx1 vector that maps the constructor's input load shapes matrix
        %> to the sorted  @c loadShapes matrix.
        sortIndices;
        
        %> Cx1 vector that maps load shapes' original cluster indices to
        %> the equivalent cluster index after clusters have been sorted
        %> by their load shape count
        centroidSortMap;
        
        %> The sort order index for the centroid of interest (coi) 
        %> identified for analysis.  It is 
        %> initialized to the most frequent centroid upon successful
        %> class construction or subsequent, successful call of
        %> calculateCentroids.  (i.e. A value of 1 refers to the centroid with fewest members,
        %> while a value of C refers to the centroid with the most members (as seen in histogram)
        coiSortOrder;  
        
        %> A line handle for updating clustering performace.  Default is
        %> -1, which means that clustering performance is not displayed.
        %> This value is initialized in the constructor based on input
        %> arguments.
        performanceLineHandle;
        
        %> Similar to performance line, but is an axes handle.
        performanceAxesHandle;
        
        %> Text handle to send status updates to via set(textHandle,'string',statusString) type calls.
        statusTextHandle;
        
        %> Measure of performance.  Currently, this is the Calinski index.
        performanceMeasure;
    end

            
    methods        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c clusterThreshold [1.5]                  
        %> @param Optional axes or line handle for displaying clustering progress.
        %> - If argument is a handle to a MATLAB @b axes, then a line handle
        %> will be added to the axes and adjusted with clustering progress.
        %> - If argument is a handle to a MATLAB @b line, then the handle
        %> will be manipulated directly in its current context (i.e. whatever
        %> axes it currently falls under).
        %> - If argument is not included, empty, or is not a line or
        %> axes handle then progress will only be displayed to the console
        %> (default)
        %> @note Including a handle increases processing time as additional calculations
        %> are made to measuring clustering separation and performance.
        %> @param Optional text handle to send status updates to via set(textHandle,'string',statusString) type calls.
        %> Status updates are sent to the command window by default.
        %> @retval Instance of PACentroid on success.  Empty matrix on
        %> failure.
        % ======================================================================        
        function this = PACentroid(loadShapes,settings,axesOrLineH,textHandle)            
            
            this.init();
            if(nargin<4)
                textHandle = [];
                if(nargin<3)
                    axesOrLineH = [];
                    if(nargin<2)
                        settings = [];
                    end
                end
            end

            if(isempty(settings))
                N = size(loadShapes,1);
                settings.minClusters = 10;
                settings.maxClusters = ceil(N/2);
                settings.clusterThreshold = 0.2;
            end
            if(~isempty(textHandle) && ishandle(textHandle) && strcmpi(get(textHandle,'type'),'uicontrol') && strcmpi(get(textHandle,'style'),'text'))
                this.statusTextHandle = textHandle;
            else
                this.statusTextHandle = -1;
            end
            
            if(~isempty(axesOrLineH) && ishandle(axesOrLineH))
                handleType = get(axesOrLineH,'type');
                if(strcmpi(handleType,'axes'))
                    this.performanceAxesHandle = axesOrLineH;
                    this.performanceLineHandle = line('parent',axesOrLineH,'xdata',nan,'ydata',nan,'linestyle',':','marker','o');
                elseif(strcmpi(handleType,'line'))
                    this.performanceLineHandle = axesOrLineH;
                    set(this.performanceLineHandle,'xdata',nan,'ydata',nan,'linestyle',':','marker','o');
                    this.performanceAxesHandle = get(axesOrLineH,'parent');
                else
                    this.performanceAxesHandle = -1;
                    this.performanceLineHandle = -1;
                end
            else
                this.performanceLineHandle = -1;
            end
            
            this.performanceMeasure = [];
            this.settings.thresholdScale = settings.clusterThreshold;
            %/ Do not let K start off higher than 
            this.settings.minClusters = min(floor(size(loadShapes,1)/2),settings.minClusters);
            
            if(isfield(settings,'maxCluster'))                
                maxClusters = settings.maxClusters;
            else
                maxClusters = ceil(size(loadShapes,1)/2);
            end
            
            this.settings.maxClusters = maxClusters;
            this.loadShapes = loadShapes;
            this.calculateCentroids();  
        end
        
        
        % ======================================================================
        %> @brief Determines if clustering failed or succeeded (i.e. do centroidShapes
        %> exist)
        %> @param Instance of PACentroid        
        %> @retval failedState - boolean
        %> - @c true - The clustering failed
        %> - @c false - The clustering succeeded.
        % ======================================================================
        function failedState = failedToConverge(this)
            failedState = isempty(this.centroidShapes);
        end        
        
        
        function distribution = getHistogram(this)
            distribution = this.histogram;
        end
        % ======================================================================
        %> @brief Returns the number of centroids/clusters obtained.
        %> @param Instance of PACentroid        
        %> @retval Number of centroids/clusters found.
        % ======================================================================
        function n = numCentroids(this)
            n = size(this.centroidShapes,1);
        end        
        
        % ======================================================================
        %> @brief Returns the number of load shapes clustered.
        %> @param Instance of PACentroid        
        %> @retval Number of load shapes clustered.
        % ======================================================================
        function n = numLoadShapes(this)
            n = size(this.loadShapes,1);
        end        
        
        % ======================================================================
        %> @brief Initializes (sets to empty) member variables.  
        %> @param Instance of PACentroid        
        %> @note Initialzed member variables include
        %> - loadShape2CentroidShapeMap
        %> - centroidShapes
        %> - histogram
        %> - loadShapes
        %> - sortIndices
        %> - coiSortOrder        
        % ======================================================================                
        function init(this)
            this.load2centroidMap = [];
            this.centroidShapes = [];
            this.histogram = [];
            this.loadShapes = [];
            this.sortIndices = [];
            this.coiSortOrder = [];
        end
        
        function increaseCOISortOrder(this)
            if(this.coiSortOrder<this.numCentroids())
                this.coiSortOrder=this.coiSortOrder+1;
            end
        end
        
        function decreaseCOISortOrder(this)
            if(this.coiSortOrder>1)
                this.coiSortOrder = this.coiSortOrder-1;
            end
        end
        
        function didChange = setCOISortOrder(this, sortOrder)
            sortOrder = round(sortOrder);
            if(sortOrder<=this.numCentroids() && sortOrder>0)
                this.coiSortOrder = sortOrder;
                didChange = true;
            else
                didChange = false;
            end
        end
        
        
        function performance = getClusteringPerformance(this)
            performance = this.performanceMeasure;
        end
        
        
        % ======================================================================
        %> @brief Returns a descriptive struct for the centroid of interest (coi) 
        %> which is determined by the member variable coiSortOrder.
        %> @param Instance of PACentroid
        %> @retval Structure for centroid of interest.  Fields include
        %> - @c sortOrder The sort order of coi.  If all centroids are placed in
        %> a line numbering from 1 to the number of centroids in increasing order of
        %> the number of load shapes the centroid has clustered to it, then the sort order
        %> is the value of the number on the line for the coi.  The sort order of
        %> a coi having the fewest number of load shape members is 1, while the sort
        %> sort order of a coi having the largest proportion of load shape members has 
        %> the value C (centroid count).
        %> - @c index - id of the coi.  This is its original, unsorted
        %> index value which is the range of [1, C]
        %> - @c shape - 1xM vector.  The coi.
        %> - @c memberIndices = Lx1 logical vector indices of member shapes
        %> obtained from the loadShapes member variable, for the coi.  L is
        %> the number of load shapes (see numLoadShapes()).
        %> @note memberShapes = loadShapes(memberIndices,:)
        %> - @c memberShapes - NxM array of load shapes clustered to the coi.
        %> - @c numMembers - N, the number of load shapes clustered to the coi.
        % ======================================================================        
        function coi = getCentroidOfInterest(this)
            coi.sortOrder = this.coiSortOrder;
            coi.index = this.centroidSortMap(coi.sortOrder);           
            coi.shape = this.centroidShapes(coi.index,:);
            coi.memberIndices = coi.index==this.load2centroidMap;
            coi.memberShapes = this.loadShapes(coi.memberIndices,:);
            coi.numMembers = size(coi.memberShapes,1);
        end
        
        
        % ======================================================================
        %> @brief Clusters input load shapes by centroid using adaptive
        %> k-means, determines the distribution of centroids by load shape
        %> frequency, and stores the sorted centroids, load shapes, and
        %> distribution, and sorted indices vector as member variables.
        %> See reset() method for a list of instance variables set (or reset on
        %> failure) from this method.
        %> @param Instance of PACentroid
        %> @param inputLoadShapes
        %> @param Structure of centroid configuration parameters.  These
        %> are passed to adaptiveKmeans method.        
        % ======================================================================
        function calculateCentroids(this, inputLoadShapes, inputSettings)

            if(nargin<3)
                inputSettings = this.settings;
                if(nargin<2)
                    inputLoadShapes = this.loadShapes;
                end
            end
            useDefaultRandomizerSeed = true;
            
            [this.load2centroidMap, this.centroidShapes, this.performanceMeasure] = this.adaptiveKmeans(inputLoadShapes,inputSettings, useDefaultRandomizerSeed,this.performanceAxesHandle,this.statusTextHandle);
            if(~isempty(this.centroidShapes))                
                [this.histogram, this.centroidSortMap] = this.calculateAndSortDistribution(this.load2centroidMap);%  was -->       calculateAndSortDistribution(this.load2centroidMap);
                this.coiSortOrder = this.numCentroids();
            else
                fprintf('Clustering failed!  No clusters found!\n');
                this.init();     
            end
        end
        
        %> @brief Calculates within-cluster sum of squares (WCSS); a metric of cluster tightness.  
        %> @note This measure is not helpful when clusters are not well separated (see @c getCalinskiHarabaszIndex).
        %> @param Instance PACentroid
        %> @retval The within-cluster sum of squares (WCSS); a metric of cluster tightness
        function wcss = getWCSS()
            fprintf(1,'To be finished');
            wcss = [];
            
        end

        
    end

    methods(Static, Access=private)
        % ======================================================================
        %> @brief Calculates the distribution of load shapes according to
        %> centroid, in ascending order.
        % @param Instance of PACentroid
        %> @param loadShapeMap Nx1 vector of centroid indices.  Each
        %> element's position represents the loadShape.  
        %> @note This is the @c @b idx parameter returned from kmeans
        % @param number of centroids (i.e number of bins/edges to use when
        % calculating the distribution)
        %> @retval
        %> @retval        
        % ======================================================================
        function [sortedCounts, sortedIndices] = calculateAndSortDistribution(loadShapeMap)
            centroidCounts = histc(loadShapeMap,1:max(loadShapeMap));
            [sortedCounts,sortedIndices] = sort(centroidCounts);
            %             this.histogram = sortedCounts;
            %             this.centroidSortMap = sortedIndices;
        end
    end
    
    methods(Static)
        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c thresholdScale [1.5]        
        %> @param Boolean
        %> @param Boolean Set randomizer seed to default
        %> - @c true Use 'default' for randomizer (rng)
        %> - @c false (default) Do not update randomizer seed (rng).
        %> - @c true Display calinski index at each adaptive k-means iteration (slower)
        %> - @c false (default) Do not calcuate Calinzki index.
        %> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
        %> @retval centroids - KxC matrix of cluster centroids.
        % ======================================================================
        function [idx, centroids, performanceIndex] = adaptiveKmeans(loadShapes,settings,defaultRandomizer,performanceAxesH,textStatusH)
            performanceIndex = [];
            % argument checking and validation ....
            if(nargin<5)
                textStatusH = -1;
                if(nargin<4)
                    performanceAxesH = -1;
                    if(nargin<3)
                        defaultRandomizer = false;
                        if(nargin<2)
                            settings.minClusters = 40;
                            settings.maxClusters = size(loadShapes,1)/2;
                            settings.thresholdScale = 5; %higher threshold equates to fewer clusters.
                        end
                    end
                end
            end
            
            if(defaultRandomizer)
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
                ylabel(performanceAxesH,'Calinksi Index');
                X = [];
                Y = [];
            end
            
            idx = [];
            K = settings.minClusters;
            
            N = size(loadShapes,1);
            % prime the kmeans algorithms starting centroids
            centroids = loadShapes(randperm(N,K),:);
            % prime loop condition since we don't have a do while ...
            numNotCloseEnough = settings.minClusters;
            firstLoop = true;
            while(numNotCloseEnough>0 && K<=settings.maxClusters)
                if(~firstLoop)
                    if(numNotCloseEnough==1)
                        statusStr = sprintf('1 cluster was not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);                        
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

                    firstLoop = false;
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
                [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop');
                
                %    [~, centroids, sumOfPointToCentroidDistances] = kmeans(loadShapes,K,'EmptyAction','drop');
                if(ishandle(performanceAxesH))
                    performanceIndex  = PACentroid.getCalinskiHarabaszIndex(idx,centroids,sumD);
                    X(end+1)= K;
                    Y(end+1)=performanceIndex;
                    plot(performanceAxesH,X,Y,'linestyle',':','marker','o');
                    xlabel(performanceAxesH,'K');
                    ylabel(performanceAxesH,'Calinksi Index');
                    
                    statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);
                    
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
                    [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off');
                                        
                    if(ishandle(performanceAxesH))
                        performanceIndex  = PACentroid.getCalinskiHarabaszIndex(idx,centroids,sumD);
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        plot(performanceAxesH,X,Y,'linestyle',':','marker','o');
                        xlabel(performanceAxesH,'K');
                        ylabel(performanceAxesH,'Calinksi Index');
                        
                        statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',pefromanceIndex,K);

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
                distanceToCentroids = pointToClusterDistances(point2centroidDistanceIndices);
                sqEuclideanCentroids = (sum(centroids.^2,2));
                
                clusterThresholds = settings.thresholdScale*sqEuclideanCentroids;
                notCloseEnoughPoints = distanceToCentroids>clusterThresholds(idx);
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
                                [~,splitCentroids] = kmeans(clusteredLoadShapes,2,'EmptyAction','drop');
                                
                            catch me
                                showME(me);
                            end
                            centroids = [centroids;splitCentroids];
                        else
                            if(numClusteredLoadShapes~=1)
                                echo(numClusteredLoadShapes); %houston, we have a problem.
                            end
                            numNotCloseEnough = numNotCloseEnough-1;
                            centroids = [centroids;clusteredLoadShapes];
                        end
                        % for speed
                        %[~,centroids(curRow:curRow+1,:)] = kmeans(clusteredLoadShapes,2);
                        %curRow = curRow+2;
                    end
                    
                    % reset cluster centers now / batch update
                    K = K+numNotCloseEnough;
                    [~, centroids] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off');
                end
                
            end
            
            if(numNotCloseEnough~=0)
                statusStr = sprintf('Failed to converge using a maximum limit of %u clusters.',settings.maxClusters);
                fprintf(1,'%s\n',statusStr);
                if(ishandle(textStatusH))
                    curString = get(textStatusH,'string');
                    set(textStatusH,'string',{curString(end);statusStr});
                    drawnow();
                end

            else
                
                if(ishandle(performanceAxesH))
                    if(ishandle(performanceAxesH))
                        performanceIndex  = PACentroid.getCalinskiHarabaszIndex(idx,centroids,sumD);
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        plot(performanceAxesH,X,Y,'linestyle',':','marker','o');
                        xlabel(performanceAxesH,'K');
                        ylabel(performanceAxesH,'Calinksi Index');
                        
                        statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);

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
                statusStr = sprintf('Converged with a cluster size of %u.',K);
                fprintf(1,'%s\n',statusStr);
                if(ishandle(textStatusH))
                    curString = get(textStatusH,'string');
                    set(textStatusH,'string',[curString(end);statusStr]);                    
                end
            end             
        end
        
        
                
        %> @brief Validation metric for cluster separation.   Useful in determining if clusters are well separated.  
        %> If clusters are not well separated, then the Adaptive K-means threshold should be adjusted according to the segmentation resolution desired.
        %> @note See Calinski, T., and J. Harabasz. "A dendrite method for cluster analysis." Communications in Statistics. Vol. 3, No. 1, 1974, pp. 1?27.
        %> @note See also http://www.mathworks.com/help/stats/clustering.evaluation.calinskiharabaszevaluation-class.html 
        %> @param Vector of output from mapping loadShapes to parent
        %> centroids.
        %> @param Centroids calculated via kmeans
        %> @param sum of euclidean distances
        %> @retval The Calinzki-Harabasz index
        function calinskiIndex = getCalinskiHarabaszIndex(loadShapeMap,centroids,sumD)
            [sortedCounts, sortedIndices] = PACentroid.calculateAndSortDistribution(loadShapeMap);
            sortedCentroids = centroids(sortedIndices,:);
            numObservations = numel(loadShapeMap);
            numCentroids = size(centroids,1);
            globalMeans = mean(sortedCentroids,1);
            
            ssWithin = sum(sumD,1);
            ssBetween = (pdist2(sortedCentroids,globalMeans)).^2;
            ssBetween = sortedCounts(:)'*ssBetween(:);  %inner product
            calinskiIndex = ssBetween/ssWithin*(numObservations-numCentroids)/(numCentroids-1);
        end
        
    end
    
end

