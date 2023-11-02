% COMPUTEMAPPING Computes a mapping between rows of matrices x and y based on the specified distance or similarity metric.
% 
% This function calculates the mapping between rows of x and y using a chosen
% method. It supports various methods including cross-correlation, Euclidean 
% distance, Mahalanobis distance, cosine similarity, Manhattan distance, 
% Chebyshev distance, and Hamming distance.
% 
% Each distance metric has its advantages and is suitable for specific
% types of data or scenarios. Depending on the nature of your data and the
% specific relationships you're trying to uncover, one method might be more
% appropriate than another.
%
% Inputs:
% x      - NxM matrix where N is the number of observations and M is the number of features
% y      - NxM matrix. N and M must be the same as in x
% method - (optional) String specifying the method to use. Valid values are:
%          'cross-correlation', 'euclidean', 'mahalanobis', 'cosine', 'manhattan',
%          'chebyshev', 'hamming'. If omitted, method defaults to 'cross-correlation' for M>1 
%          and 'euclidean' for M=1.
%
% Outputs:
% mapping - Nx1 vector indicating the mapping of rows from x to y
%
% Example usage:
% mapping = computeMapping(x, y, 'euclidean');
% mapping = computeMapping(x, y); % Uses default method
%
% Note: The 'hamming' method assumes binary/discrete data in x and y.
%
function mapping = computeMapping(x, y, method)
    if nargin<3
        cols = size(x,2);
        if cols>1
            method = 'cross-correlation';
        else
            method = 'euclidean';
        end
    end

    if size(x, 1) ~= size(y, 1)
        error('x and y must have the same number of rows.');
    end

    switch method
        case 'cross-correlation'
            mapping = crossCorrelationMapping(x, y);
        case 'euclidean'
            mapping = euclideanMapping(x, y);
        case 'mahalanobis'
            mapping = mahalanobisMapping(x, y);
        case 'cosine'
            mapping = cosineSimilarityMapping(x, y);
        case 'manhattan'
            mapping = manhattanMapping(x, y);
        case 'chebyshev'
            mapping = chebyshevMapping(x, y);
        case 'hamming'
            mapping = hammingMapping(x, y);
        otherwise
            error('Unknown method. Please select a valid method.');
    end
end

function mapping = crossCorrelationMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    for i = 1:N
        correlations = arrayfun(@(j) max(xcorr(x(i,:), y(j,:), 'coeff')), 1:N);
        [~, index] = max(correlations);
        mapping(index) = i;
    end
end

function mapping = euclideanMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    for i = 1:N
        distances = vecnorm(y - x(i,:), 2, 2);
        [~, index] = min(distances);
        mapping(index) = i;
    end
end

function mapping = mahalanobisMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    C = cov(x); % covariance matrix
    for i = 1:N
        distances = arrayfun(@(j) mahal(x(i,:), y(j,:)), 1:N);
        [~, index] = min(distances);
        mapping(index) = i;
    end
end

function mapping = cosineSimilarityMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    for i = 1:N
        similarities = arrayfun(@(j) dot(x(i,:), y(j,:)) / (norm(x(i,:)) * norm(y(j,:))), 1:N);
        [~, index] = max(similarities);
        mapping(index) = i;
    end
end

% Manhattan (L1) Distance: The Manhattan distance (also known as the L1
% distance or taxicab distance) computes the distance between two vectors
% as the sum of their absolute differences. This can sometimes capture
% differences more effectively when the Euclidean distance (L2) is not as
% discriminating.
function mapping = manhattanMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    for i = 1:N
        distances = arrayfun(@(j) sum(abs(x(i,:) - y(j,:))), 1:N);
        [~, index] = min(distances);
        mapping(index) = i;
    end
end


% Chebyshev (L∞) Distance: The Chebyshev distance measures the maximum
% absolute difference between elements of vectors. It can be especially
% useful when the maximum difference is of interest, rather than the
% cumulative difference.
function mapping = chebyshevMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    for i = 1:N
        distances = arrayfun(@(j) max(abs(x(i,:) - y(j,:))), 1:N);
        [~, index] = min(distances);
        mapping(index) = i;
    end
end

% Hamming Distance: Hamming distance is generally used for binary vectors
% and calculates the number of differing positions. It can be useful if
% your data is binarized or discretized.
% Note: Use Hamming distance only if x and y are binary or discrete.
function mapping = hammingMapping(x, y)
    N = size(x, 1);
    mapping = zeros(1, N);
    for i = 1:N
        distances = arrayfun(@(j) sum(x(i,:) ~= y(j,:)), 1:N);
        [~, index] = min(distances);
        mapping(index) = i;
    end
end
