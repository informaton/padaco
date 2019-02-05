function mPathname = pathsetup(mPathname)
    if(nargin<1 || ~isdir(mPathname))
        mPathname = fileparts(mfilename('fullpath'));
    end
    if(~isdeployed)
        addpath(mPathname);
        %       ,'stats/stats'};  % Added stats, a symbolically linked folder to something else
        subPaths = {'abstract','widgets','figures','utility','events','resources','resources/html','resources/icons','model','tools'};  
        for s=1:numel(subPaths)
            addpath(fullfile(mPathname,subPaths{s}));
        end
        
        try
           addpath(fullfile(mPathname,'../matlab/models'));
           addpath(fullfile(mPathname,'../matlab/gee'));           
        catch me
            showME(me);
        end
    end
end