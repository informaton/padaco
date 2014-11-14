function adaptiveKmeans(loadShapes,minClusters, maxClusters)
initialCenters = [];    
K = minClusters;
    

while(1)
    kmeans(loadShapes,K);
    
end
    
    


end