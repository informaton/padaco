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
        %> to the sorted, instance variable loadShapes matrix.
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
    end

            
    methods        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c clusterThreshold [1.5]                  
        %> @retval Instance of PACentroid on success.  Empty matrix on
        %> failure.
        % ======================================================================        
        function this = PACentroid(loadShapes,settings)            
            
            this.init();

            this.settings.thresholdScale = settings.clusterThreshold;
            this.settings.minClusters = settings.minClusters;
            
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
        
        % ======================================================================
        %> @brief 
        %> @param Instance of PACentroid
        %> @retval Structure for centroid of interes.  Fields include
        % ======================================================================        
        function coi = getCentroidOfInterest(this)
            coi.sortOrder = this.coiSortOrder;
            coi.index = this.centroidSortMap(coi.sortOrder);           
            coi.shape = this.centroidShapes(coi.index,:);
            coi.memberShapes = this.loadShapes(coi.index==this.load2centroidMap,:);
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
            
            [this.load2centroidMap, this.centroidShapes] = this.adaptiveKmeans(inputLoadShapes,inputSettings);
            if(~isempty(this.centroidShapes))
                this.calculateAndSortDistribution(this.load2centroidMap);
                % [this.histogram, this.centroidSortMap] = this.calculateDistributionAndSort(loadShapeMap);
                this.coiSortOrder = this.numCentroids();
            else
                fprintf('Clustering failed!  No clusters found!\n');
                this.init();     
            end
        end
        
    end

    methods(Access=private)
        % ======================================================================
        %> @brief Calculates the distribution of load shapes according to
        %> centroid, in ascending order.
        %> @param Instance of PACentroid
        %> @param loadShapeMap Nx1 vector of centroid indices.  Each
        %> element's position represents the loadShape
        %> @param number of centroids (i.e number of bins/edges to use when
        %> calculating the distribution)
        % ======================================================================
        function [sortedCounts, sortedIndices] = calculateAndSortDistribution(this,loadShapeMap)
            centroidCounts = histc(loadShapeMap,1:max(loadShapeMap));
            [sortedCounts,sortedIndices] = sort(centroidCounts);
            this.histogram = sortedCounts;
            this.centroidSortMap = sortedIndices;
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
        %> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
        %> @retval centroids - KxC matrix of cluster centroids.
        % ======================================================================
        function [idx, centroids] = adaptiveKmeans(loadShapes,settings)
            if(nargin<2)
                settings.minClusters = 40;
                settings.maxClusters = size(loadShapes,1)/2;
                settings.thresholdScale = 1.5; %higher threshold equates to fewer clusters.
            end
            idx = [];
            K = settings.minClusters;
            
            
            
            N = size(loadShapes,1);
            % prime the kmeans algorithms starting centroids
            centroids = loadShapes(randperm(N,K),:);
            % prime loop condition since we don't have a do while ...
            numNotCloseEnough = settings.minClusters;
            
            while(numNotCloseEnough>0 && K<=settings.maxClusters)
                fprintf('%u were not close enough.  Setting cluster size to %u.\n',numNotCloseEnough,K);
                
                tic
                [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop');
                
                %    [~, centroids, sumOfPointToCentroidDistances] = kmeans(loadShapes,K,'EmptyAction','drop');
                
                removed = sum(isnan(centroids),2)>0;
                numRemoved = sum(removed);
                if(numRemoved>0)
                    fprintf('%u clusters were dropped during this iteration.\n',numRemoved);
                    centroids(removed,:)=[];
                    K = K-numRemoved;
                    [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off');
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
                fprintf('Failed to converge using a maximum limit of %u clusters.\n',settings.maxClusters);
            else
                fprintf('Converged with a cluster size of %u.\n',K);
                
            end
        end
    end
    
end

