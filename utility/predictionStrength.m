function [optimal_k, avg_prediction] = predictionStrength(features, varargin)
    narginchk(1, inf);
    
    defaults = struct('minK',2,'maxK',5,'M',100,'clusterMethod',@kmeans,...
        'classification', 'centroid', 'cutoff', 0.8,...
        'nkk', 1, 'distances',[], 'showProgress', false, 'gui', false);
    params = mergeStructi(defaults, struct(varargin{:}));
    
    minK = params.minK;
    maxK = params.maxK;
    distances = params.distances;
    cutoff = params.cutoff;
    classification = params.classification;
    M = params.M;
    showProgress = params.showProgress;
    clusterMethod = params.clusterMethod;
    nnk = params.nkk;
        
    %     features <- as.matrix(features)
    nRows  = size(features,1);
    shouldCancel = false;
    pct = 0;
    h = [];
    function cancelFunc(varargin)
        if ishandle(h)
            waitbar(pct, h, 'Cancelling...');
            shouldCancel = true;
        end
    end
    if params.gui        
        figTitle = sprintf('Evaluating prediction strength (max=%d)', maxK);        
        h = waitbar(pct,'Determining K', 'name', figTitle,'CreateCancelBtn',@cancelFunc);         
        set(h,'closerequestfcn','delete(gcbo)');
    end
    
    
    % Split sizes
    nf = [floor(nRows/2), nRows-floor(nRows/2)];
    
    % corrpred = zeros(maxK,M);
    corrpred = nan(maxK,M);
    
    num_evaluations = maxK-minK+1;
    
    for k=minK:maxK
        if shouldCancel
            break;
        end
        if (showProgress)
            fprintf('%d clusters\n',k)
            if ishandle(h)
                msg = sprintf('Evaluating K = %d',k);
                pct = (k-minK)/num_evaluations;
                waitbar(pct, h, msg);
            end
        end
        for l = 1:M
            if shouldCancel
                break
            end
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
    

    avg_prediction = mean(corrpred,2);
    if minK < 1
        avg_prediction(1) = 0;
    else
        avg_prediction(1) = 1;
        avg_prediction(2:minK-1) = nan;
    end
    
    if showProgress
        disp(avg_prediction');
        for k = 1:maxK
            fprintf('%6d, ', k); 
        end
        fprintf('\b\b%c%c\n',127, 127); % two backspaces and possibly two deletes if backspace is not destructive
        for k = 1:maxK
            fprintf('%6.04f, ', avg_prediction(k));
        end
        fprintf('\b\b\n');
    end
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
        msg = sprintf('\n\tOptimal K is %d\n\n', optimal_k);
        for k = 1:maxK
            pred = avg_prediction(k);
            msg = [msg, sprintf('\t(%02d): %6.04f', k, pred)];            
            if mod(k, 5)==0
                msg = [msg, '   _|', newline newline];
            end
        end
        if shouldCancel
            pa_msgbox(msg,'User canceled');
        else
            pa_msgbox(msg,'Predictive strength of K');
        end
    end
    
    
end