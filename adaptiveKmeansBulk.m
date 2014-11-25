function adaptiveKmeansBulk(loadShapes,minClusters, maxClusters)
if(nargin==0)
    featureStruct = loadAlignedFeatures();
    loadShapes = featureStruct.values;
    minClusters = 20;
    maxClusters = 5000;
    thresholdChoice = 1;
end

K = minClusters;

%loadShapes - RxC matrix to  be clustered (Each row represents a C dimensional value).
%idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
%centroids - KxC matrix of cluster centroids.


% prime the kmeans algorithms starting centroids
centroids = loadShapes(randperm(size(loadShapes,1),K),:);
% prime loop condition since we don't have a do while ...
numNotCloseEnough = K;  

while(numNotCloseEnough~=0 && K<=maxClusters)
    fprintf('%u were not close enough.  Setting cluster size to %u.\n',numNotCloseEnough,K);
    
    tic
    [~, centroids, sumOfPointToCentroidDistances] = kmeans(loadShapes,K,'EmptyAction','drop');
    toc
    removed = sum(isnan(centroids),2)>0;
    numRemoved = sum(removed);
    if(numRemoved>0)
        fprintf('%u clusters were dropped during this iteration.\n',numRemoved);
        centroids(removed)=[];
        K = K-sum(removed);
    end

    sumOfSquaredCentroids = sum(centroids.^2,2);
    notCloseEnough = sumOfPointToCentroidDistances>(thresholdChoice*sumOfSquaredCentroids);
    numNotCloseEnough = sum(notCloseEnough);
    K = K+numNotCloseEnough;
    
end

if(numNotCloseEnough~=0)
    fprintf('Failed to converge using a maximum limit of %u clusters.\n',maxClusters);
else
   fprintf('Converged with a cluster size of %u.\n',K);
     
end
    
    


end