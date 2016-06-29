function mPathname = pathsetup()
    mPathname = fileparts(mfilename('fullpath'));
    if(~isdeployed)
        addpath(mPathname);
        subPaths = {'widgets','figures','icons','utility','html','events'};
        for s=1:numel(subPaths)
            addpath(fullfile(mPathname,subPaths{s}));
        end
    end
    addpath(mPathname);
    subPaths = {'widgets','figures','icons','utility','html','events'};
    for s=1:numel(subPaths)
        addpath(fullfile(mPathname,subPaths{s}));
    end
end
