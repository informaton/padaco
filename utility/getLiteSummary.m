function stat = getLiteSummary(x,percent_threshold)
    
    if(nargin<1)
        x= [];
    end
    
    if(iscell(x))
        x= cell2mat(x);
    end
    
    x = x(~isnan(x));
    stat.n = numel(x);
    stat.n_above = [];
    stat.n_below = [];
    stat.mx = [];
    stat.var = [];
    stat.sem = [];
    stat.ci_95th = [];
    stat.median = [];

    stat.string = [];
        
    if(islogical(x) && nargin==1)
        percent_threshold = 0;
    end
    if(nargin>1 || islogical(x))
        n_above = sum(x>percent_threshold);
        stat.n_above = n_above;
        %         stat.n_below = sum(x<=percent_threshold);
        stat.n_below = stat.n-n_above;
        in_excess = n_above/stat.n*100;
        
        stat.string = sprintf('%0.2f%%',in_excess);
    else
        stat.var = var(x);
        stat.sem = sqrt(stat.var/stat.n);
        stat.mx = mean(x);
        stat.median = median(x);
        Z = 1.96;        
        % A ref: https://www.mathsisfun.com/data/confidence-interval.html
        stat.ci_95th = stat.mx+Z*std(x)/sqrt(stat.n)*[-1, 1];
        stat.median_ci_95th = stat.median+Z*std(x)/sqrt(stat.n)*[-1, 1];
        
        % Same as above: stat.ci_95th = stat.mx+Z*stat.sem*[-1, 1];
        
        stat.string = sprintf('%0.2f',stat.mx);
    end

end