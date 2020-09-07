%a = load('iris.txt','-ascii');
% iris_features = a(2:end,:);
load fisheriris.mat; % now have variables meas and species
iris_features = meas;
optimal_k = predictionStrength(iris_features);
disp(optimal_k)

data is nxp matrix, where n is number of observations and p is number of variables/features per observation

optimal_k = predictionStrength(centroidObj.loadShapes, 'mink', 2, 'maxk', 30, 'M', 20, 'showprogress', true);


optimal_k = predictionStrength(loadShapes, 'mink', 2, 'maxk', 40, 'M', 20, 'showprogress', true);


loadShapes = centroidObj.loadShapes;

[idx, cshape]  = kmeans(loadShapes, 6);
save('loadshapes.txt', 'loadShapes', '-ascii');

Normalized feature vectors

   1.0000    0.9732    0.9498    0.9718    0.7674    0.6683    0.6634    0.5336    0.4192    0.4514    0.3291    0.3353    0.3525    0.2594    0.2757    0.2116    0.2309    0.2283    0.1882    0.1699

Default feature vectors

   1.0000    0.9732    0.9498    0.9718    0.7674    0.6683    0.6634    0.5336    0.4192    0.4514    0.3291    0.3353    0.3525    0.2594    0.2757    0.2116    0.2309    0.2283    0.1882    0.1699
