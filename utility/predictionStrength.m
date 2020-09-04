function optimal_k = predictionStrength(features, varargin)
    narginchk(1, inf);
    defaults = struct('minK',2,'maxK',5,'M',100,'clusterMethod',@kmeans,...
        'classification', 'centroid', 'centroidName', [], 'cutoff', 0.8,...
        'nkk', 1, 'distances',[], 'showProgress', false, 'gui', false);    
    params = mergeStructi(defaults, struct(varargin{:}));
    
    minK = params.minK;
    maxK = params.maxK;
    distances = params.distances;
    cutoff = params.cutoff;
    classification = params.classification;
    M = params.M;
    showProgress = params.showProgress;
    centroidName = params.centroidName;
    clusterMethod = params.clusterMethod;
    nnk = params.nkk;
    
    
    %     features <- as.matrix(features)
    nRows  = size(features,1);
    
    if params.gui
        h = waitbar(0,'Determining K', 'name', sprintf('Evaluating prediction strength (max=%d)', maxK));
    else
        h = [];
    end

    
    % Split sizes
    nf = [floor(nRows/2), nRows-floor(nRows/2)];

    % corrpred = zeros(maxK,M);
    corrpred = nan(maxK,M);
    
    num_evaluations = maxK-minK+1;
    
    for k=minK:maxK
        if (showProgress)
            fprintf('%d clusters\n',k)  
            if ishandle(h)
                msg = sprintf('Evaluating K = %d',k);
                pct = (k-minK)/num_evaluations;
                waitbar(pct, h, msg);
            end
        end
        for l = 1:M
            nperm = randperm(nRows);  % randomly, not repeating, indices selected from the data.
            if (showProgress)                
                fprintf(' Run %d\n',l);
            end
            if ishandle(h)
                pct = (k-minK+(l-1)/M)/num_evaluations;
                waitbar(pct, h, msg);
            end
            indvec = {nperm(1:nf(1)), nperm(nf(1)+1:end)};
            clusterings = cell(2,1);
            classifications = cell(2,1);
            jclusterings = repmat(-1, 2, nRows);
            clcenters = cell(2,1);

            for i = 1:2
                if (distances)
                    [clusterings{i}, clcenters{i}] = clusterMethod(as.dist(features(indvec{i}, indvec{i}), k));
                else
                    [clusterings{i}, clcenters{i}] = clusterMethod(features(indvec{i}, :), k);
                end                
                % jclusterings(i, indvec{i}) = clusterings{i}$partition
                centroids = clcenters{i};
                jclusterings(i, indvec{i}) = clusterings{i};

                j = 3 - i;
                if (distances)
                    classifDist = classifdist(as.dist(features), jclusterings(i,:), classification, centroids, nnk);                    
                else
                    classifDist = classifnp(features, jclusterings(i,:), classification, [], centroids, nnk);
                end
                classifications{j} = classifDist(indvec{j});
            end            
            ps = zeros(2, k);
            for i = 1:2
                %ctable = [clusterings{i}(:), classifications{i}(:)];  %ctable = table(clusterings{i}, classifications{i}, k);
                %ctable_matches = ctable(:,1) == ctable(:,2);
                ctable = crosstab(clusterings{i}(:), classifications{i}(:));
                try
                    tmp_ps = sum(ctable.^2-ctable, 2);  %sometimes not everything gets classified ...
                    ps(i, 1:numel(tmp_ps)) = tmp_ps;
                catch me
                    showME(me);
                end
                for kk = 1:k
                    % cpik = clusterings{i}(:) == kk; %              cpik = clusterings{i}.partition == kk;                     
                    % ps(i, kk) = sum(ctable.^2 - ctable(kk,:)); % ps(i, kk) = sum(ctable(kk, :)^2 - ctable(kk,:));
                    nik = sum(clusterings{i}(:) == kk);
                    if nik > 1
                        ps(i, kk) = ps(i, kk)/(nik^2-nik);
                    else
                        ps(i, kk) = 1;
                    end
                    
                end
            end
            corrpred(k,l) = mean([min(ps(1,: )), min(ps(2,:))]);
        end
    end
    
    % TODO
    avg_prediction = mean(corrpred,2);
    
    %avg_prediction = nan(maxK,1);    
    

    %avg_prediction(minK:maxK) = mean(corrpred,2);
    if minK < 1
        avg_prediction(1) = 0;
    else
        avg_prediction(1) = 1;
        avg_prediction(2:minK-1) = nan;
    end
    
    % for k = minK:maxK
    %    avg_prediction(k) = mean(corrpred(k, :));        
    % end
    disp(avg_prediction');
    optimal_k = find(avg_prediction> cutoff, 1, 'last');  %max(which(mean.pred > cutoff))
    %out <- list(predcorr = corrpred, mean.pred = mean.pred, optimalk = optimalk, 
    %    cutoff = cutoff, method = clusterings{1}$clustermethod, 
    %    maxK = maxK, M = M)
    %class(out) = 'predstr'    
    %out
    if params.gui
        if ishandle(h)
            delete(h)
        end
        msg = sprintf('\nOptimal K is %d', optimal_k);
        for k = 1:maxK            
            if mod(k, 5)==1
                msg = [msg, newline newline];
            end
            msg = [msg, sprintf('\t(%02d): %0.04f', k, avg_prediction(k))];
        end
        pa_msgbox(msg)
    end
    

end