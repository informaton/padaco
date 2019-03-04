%> @param Clusters calculated via kmeans
%> @param sum of euclidean distances
%> @retval The Calinzki-Harabasz index
function calinskiIndex = calinski(clusterIDForClusterMember,clusters,sumD)
try
    membersPerCluster = histcounts(clusterIDForClusterMember, numel(sumD));  %or size(clusters,1)
    numObservations = sum(membersPerCluster(:));
    numClusters = size(clusters,1);
    globalMeans = mean(clusters,1);
    
    ssWithin = sum(sumD,1);
    ssBetween = (pdist2(clusters,globalMeans)).^2;
    ssBetween = membersPerCluster(:)'*ssBetween(:);  %inner product
    calinskiIndex = ssBetween/ssWithin*(numObservations-numClusters)/(numClusters-1);
catch me
    showME(me);
    calinskiIndex = nan;
end