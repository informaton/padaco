function predictionStrength(features, varargin)

    defaults = struct('minK',2,'maxK',5,'M',4,'clusterMethod','kmeans',...
        'classification', 'centroid', 'centroidName', [], 'cutoff', 0.8,...
        'nkk', 1, 'distances',[], 'showProgress', false);    
    params = mergeStructi(defaults, struct(varargin{:}));
    
    %     features <- as.matrix(features)
    nRows  = size(features,1);
    
    % Split sizes
    nf = [floor(nRows/2), nRows-floor(nRows/2)];

    corrpred = zeros(k,1);
    
    for k=minK:maxK
        if (showProgress)
            printf("%d clusters\n",k)
        end
        for l = 1:M
            nperm = randperm(nRows);  % randomly, not repeating, indices selected from the data.
            if (showProgress)
                printf(" Run %d\n",l);
            end
            indvec = {nperm(1:nf(1)), nperm(nf(1)+1:end)};
            clusterings = cell(2,1);
            classifications = cell(2,1);
            jclusterings = repmat(-1, 2, nRows);
            % clcenters = cell(2,1);

            for i = 1:2
                if (distances)
                    clusterings{i} = clustermethod(as.dist(features(indvec{i}, indvec{i}), k));
                else
                    clusterings{i} = clustermethod(features(indvec{i}, :), k);
                end                
                jclusterings(i, indvec{i}) = clusterings{i}$partition
                centroids = {};
                if (classification == "centroid")
                    if (is.null(centroidname))
                        if (identical(clustermethod, kmeansCBI))
                            centroidname = "centers";
                        end
                        if (identical(clustermethod, claraCBI))
                            centroidname = "medoids";
                        end
                    end
                    if ~isempty(centroidname)
                        centroids = clusterings{i}$result[centroidname][[1]]
                    end
                end
                j = 3 - i;
                if (distances)
                    classifDist = classifdist(as.dist(features), jclusterings{i}, classification, centroids, nnk);                    
                else
                    classifDist = classifnp(features, jclusterings{i}, classification, centroids, nnk);
                end
                classifications{j} = classifDist(indvec{j});
            end            
            ps = zeros(2, k);
            for i = 1:2
                ctable = table(clusterings{i}.partition, classifications{i}, k);
                for kk = 1:k
                    ps(i, kk) = sum(ctable(kk, :)^2 - ctable(kk,:));
                    cpik = clusterings{i}.partition == kk;
                    nik = sum(cpik);
                    if nik > 1
                        ps(i, kk) = ps[i, kk]/(nik * (nik - 1))
                    else
                      ps(i, kk) = 1;
                  end
                end
            end
            corrpred(k,l) = mean(c(min(ps[1, ]), min(ps[2,])))
        end
    end
    mean.pred = 0;
    if (minK > 1) 
        mean.pred  = 1;
    end
    if (minK > 2) 
        mean.pred = [mean.pred, rep(NA, minK - 2)];
    end
    for k = minK:maxK
        mean.pred = [mean.pred, mean(corrpred(k,:))];
    end
    optimalk <- max(which(mean.pred > cutoff))
    %out <- list(predcorr = corrpred, mean.pred = mean.pred, optimalk = optimalk, 
    %    cutoff = cutoff, method = clusterings{1}$clustermethod, 
    %    maxK = maxK, M = M)
    %class(out) = "predstr"
    %out

end