function normalizedLoadShapes = normalizeLoadShapes(loadShapes)

a= sum(loadShapes,2);
%nzi = nonZeroIndices
nzi = a~=0;
normalizedLoadShapes(nzi,:) = loadShapes(nzi,:)./repmat(a(nzi),1,size(loadShapes,2));

end