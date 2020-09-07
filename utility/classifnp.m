function clustering = classifnp(data, clustering, method, cdist, centroids, nnk)
    if nargin < 6
        nnk = 1;
        if nargin < 5
            centroids = [];
            if nargin < 4
                cdist = [];
                if nargin < 3
                    method = 'centroid';
                end
            end
        end
    end


    k = max(clustering);
    [n, p] = size(data);
    topredict = clustering < 0;
    switch lower(method)
        case 'averagedist'
            if (isempty(cdist))
                cdist = dist(data);
            end
            prmatrix = zeros(sum(topredict), k); % matrix(0, ncol = k, nrow = sum(topredict))
            shouldDrop = false;
            for j = 1:k
                prmatrix(: , j) = rowMeans( cdist(topredict, clustering == j, shouldDrop));
            end
            clpred = apply(prmatrix, 1, which.min);
            clustering(topredict) = clpred;
        case 'centroid'
            if (isempty(centroids))
                nrow = k;
                ncol = p;
                centroids = zeros(nrow, ncol);
                for j = 1:k
                    centroids(j, :) = colMeans((data(clustering == j, :)));
                end
            end
            clustering(topredict) = knnsearch(centroids, data(topredict,:),'k',1); % knn1(centroids, data(topredict, :), 1:k);
            %clustering(topredict) = knnsearch(centroids, data(topredict,:),'k',1); % knn1(centroids, data(topredict, :), 1:k);

        case 'qda'
            data2use = data(~topredict, :);
            grouping = as.factor(clustering(~topredict));
            try
                silent = true;
                qq = qda(data2use, grouping, silent);
            catch me
                qq = lda(data2use, grouping);
                clustering(topredict) = as.integer(predict(qq, data(topredict, :)).class);
            end
        case 'lda'
            data2use = data(~topredict, :);
            data2predict = data(topredict, :);
            grouping = as.factor(clustering(~topredict));
            qq = lda(data2use, grouping);
            clustering(topredict) = as.integer(predict(qq, data2predict).class);
        case 'knn'
            data2use = data(~topredict, :);
            k = nnk;
            clustering(topredict) = as.integer(knn(data2use, data(topredict, :), as.factor(clustering(~topredict)), k));
        case'fn'
            if (isempty(cdist))
                cdist = dist(data);
            end
            nrow = sum(topredict);
            ncol = l;
            fdist = zeros(nrow, ncol);
            for i = 1:k
                fdist(: , i) = apply((cdist(topredict, clustering == i)), 1, max);
            end
            bestobs1 = apply(fdist, 1, which.min);
            clustering(topredict) = bestobs1;
    end

end