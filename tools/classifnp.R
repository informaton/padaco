function (data, clustering, method = "centroid", cdist = NULL, 
    centroids = NULL, nnk = 1) 
{
    data <- as.matrix(data)
    k <- max(clustering)
    p <- ncol(data)
    n <- nrow(data)
    topredict <- clustering < 0
    if (method == "averagedist") {
        if (is.null(cdist)) {
            cdist <- as.matrix(dist(data))
        }
        else {
            cdist <- as.matrix(cdist)
        }
        prmatrix <- matrix(0, ncol = k, nrow = sum(topredict))
        for (j in 1:k) {
            prmatrix[, j] <- rowMeans(as.matrix(cdist[topredict, 
                clustering == j, drop = FALSE]))
        }
        clpred <- apply(prmatrix, 1, which.min)
        clustering[topredict] <- clpred
    }
    if (method == "centroid") {
        if (is.null(centroids)) {
            centroids <- matrix(0, ncol = p, nrow = k)
            for (j in 1:k) centroids[j, ] <- colMeans(as.matrix(data[clustering == 
                j, ]))
        }
        clustering[topredict] <- knn1(centroids, data[topredict, 
            ], 1:k)
    }
    if (method == "qda") {
        qq <- try(qda(data[!topredict, ], grouping = as.factor(clustering[!topredict])), 
            silent = TRUE)
        if (identical(attr(qq, "class"), "try-error")) {
            qq <- lda(data[!topredict, ], grouping = as.factor(clustering[!topredict]))
            clustering[topredict] <- as.integer(predict(qq, data[topredict, 
                ])$class)
        }
    }
    if (method == "lda") {
        qq <- lda(data[!topredict, ], grouping = as.factor(clustering[!topredict]))
        clustering[topredict] <- as.integer(predict(qq, data[topredict, 
            ])$class)
    }
    if (method == "knn") {
        clustering[topredict] <- as.integer(knn(data[!topredict, 
            ], data[topredict, ], as.factor(clustering[!topredict]), 
            k = nnk))
    }
    if (method == "fn") {
        if (is.null(cdist)) {
            cdist <- as.matrix(dist(data))
        }
        else {
            cdist <- as.matrix(cdist)
        }
        fdist <- matrix(0, nrow = sum(topredict), ncol = k)
        for (i in 1:k) {
            fdist[, i] <- apply(as.matrix(cdist[topredict, clustering == 
                i]), 1, max)
        }
        bestobs1 <- apply(fdist, 1, which.min)
        clustering[topredict] <- bestobs1
    }
    clustering
}