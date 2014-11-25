function normalizedLoadShapes = normalizeLoadShapes(loadShapes)

a= sum(loadShapes,2);

normalizedLoadShapes = loadShapes./repmat(a,1,size(loadShapes,2));
    
    


end