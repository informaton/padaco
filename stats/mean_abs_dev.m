function result = mean_abs_dev(x , dim)
    narginchk(1,2);
    if nargin<2
        dim = 1;
    end
    result = mean(abs(x-mean(x, dim, 'omitnan')));
end