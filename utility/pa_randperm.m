function p = pa_randperm(maxInt,K)

    if(nargin<2 || isempty(K))
        K = maxInt;
    end
    [~,p] = sort(rand(1,maxInt));

    p = p(1:K);
    
end