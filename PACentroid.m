% ======================================================================
%> @file PACentroid.cpp
%> @brief Class for clustering results data produced via padaco's batch
%> processing.
% ======================================================================
classdef PACentroid < handle
    
    properties(Access=private)
        %> NxM array of N profiles of length M
        loadShapes;
        %> Struct with cluster calculation settings.  Fields include
        %> - @c minClusters
        %> - @c maxClusters
        %> - @c thresholdScale
        settings;
        centroids;
        %> Nx1 vector of centroid index for loadShape profile associated with its row.
        loadShape2CentroidMap;
    end
    
    methods
        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c thresholdScale [1.5]                  
        %> @retval Instance of PACentroid
        % ======================================================================        
        function this = PACentroid(loadShapes,settings)
            this.loadShapes = loadShapes;
            this.settings.thresholdScale = settings.thresholdScale;
            this.settings.minClusters = settings.minClusters;
            
            if(isfield(settings,'maxCluster'))
                maxClusters = settings.maxClusters;
            else
                maxClusters = size(this.loadShapes,1)/2;
            end
            this.settings.maxClusters = maxClusters;
            this.calculateCentroids();
        end
        
        % ======================================================================
        % ======================================================================
        function calculateCentroids(this)
            [this.loadShape2CentroidMap, this.centroids] = this.adaptiveKmeans(this.loadShapes,this.settings);
            
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
            numNotCloseEnough = minClusters;
            
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
                fprintf('Failed to converge using a maximum limit of %u clusters.\n',maxClusters);
            else
                fprintf('Converged with a cluster size of %u.\n',K);
                
            end
        end
    end
    
end

