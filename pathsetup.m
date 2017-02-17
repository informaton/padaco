function mPathname = pathsetup()
    mPathname = fileparts(mfilename('fullpath'));
    if(~isdeployed)
        addpath(mPathname);
        subPaths = {'widgets','figures','utility','events','resources','resources/html','resources/icons','stats/stats'};  % Added stats, a symbolically linked folder to something else
        for s=1:numel(subPaths)
            addpath(fullfile(mPathname,subPaths{s}));
        end
    end
end