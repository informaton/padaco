function mPathname = pathsetup()
    mPathname = fileparts(mfilename('fullpath'));
    if(~isdeployed)
        addpath(mPathname);
        subPaths = {'widgets','figures','utility','events','resources','resources/html','resources/icons'};
        for s=1:numel(subPaths)
            addpath(fullfile(mPathname,subPaths{s}));
        end

    end
end
