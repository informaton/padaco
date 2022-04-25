function result = median_abs_dev(x , dim)
    narginchk(1,2);
    if nargin<2
        dim = 1;
    end
    result = median(abs(x-median(x, dim, 'omitnan')));
end
    