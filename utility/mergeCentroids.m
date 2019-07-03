function [centroids,idx] = mergeCentroids(centroids, targetSize, idx)
numClusters = size(centroids,1);

%normalizedCentroids = centroidSizes.^-1*centroids;
while(numClusters>targetSize)
    %find two closest cluster centers
    centroidDistances = nan(numClusters);
    
    for r=1:numClusters
        centroidDistances(:,r) = sum((centroids-repmat(centroids(r,:),numClusters,1)).^2,2);
        centroidDistances(r,r) = nan;  %don't want to include this later.
    end
    
    [~,ndx]=nanmin(centroidDistances(:));
    [i,j] = ind2sub([numClusters,numClusters],ndx);
    closestPairIndices = [i j];
    closestCentroidSizes = sqrt(sum(centroids(closestPairIndices,:).^2,2));
    
    %determine the new merged centroid
    mergedCentroid = closestCentroidSizes'*centroids(closestPairIndices,:)/sum(closestCentroidSizes);
    
    %assign the merged centroid to the first of closest cluster pair
    centroids(closestPairIndices(1),:) = mergedCentroid;
    
    % remove the second centroid of the closest cluster pair
    centroids(closestPairIndices(2),:) = [];
    
    % reassign indices from the second cluster pair to the newly merged
    % cluster index.
    idx(idx==closestPairIndices(2))=closestPairIndices(1);
    
    numClusters = size(centroids,1);
end


end