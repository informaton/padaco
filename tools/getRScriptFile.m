function rscriptFile = getRScriptFile(file2check)
    curPath = mfilename('fullpath');
    settingsFile = fullfile(curPath,'rscript.path');
    if(nargin<1 || isempty(file2check))
        if(isunix)
            file2check = '/usr/local/bin/Rscript';
        else
            file2check = 'Rscript.exe';
        end
        if(exist(settingsFile,'file'))
            file2check = load(settingsFile,'-ascii');
        end
    end
    if(exist(file2check,'file'))
        rscriptFile = file2check;
    else
        if(isunix)
            filterFile = 'Rscript';
        else
            filterFile = 'Rscript.exe';
        end
        rscriptFile = uigetfullfile(filterFile,'Select ''RScript'' program which is required to run R scripts and is installed with a standard, separate, R installation.',file2check);        
        if(exist(rscriptFile,'file'))
            save(rscriptFile,'file2check','-ascii');
        end
    end
end