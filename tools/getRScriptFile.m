% Locates the R program to be used in executing R script files.
function rscriptFile = getRScriptFile(file2check)
    curPath = mfilename('fullpath');
    settingsFile = fullfile(curPath,'rscript.path');
    
    if(nargin<1 || isempty(file2check))
        if(exist(settingsFile,'file'))
            file2check = load(settingsFile,'-ascii');
        else
            file2check = '';
        end
    end

    if(exist(file2check,'file'))
        rscriptFile = file2check;
    else
        if(ismac)
            file2check = '/usr/local/bin/';
            if(~exist(file2check,'file'))
                file2check = '/Library/Frameworks/R.framework/Resources/Rscript';
            end
            
        elseif(isunix)
            file2check = '/usr/local/bin/Rscript';
        elseif(ispc)
            file2check = 'R_HOME/bin/Rscript.exe';
        else
            file2check = 'Rscript*';  % not supported ...
        end
        
        if(exist(file2check,'file'))
            rscriptFile = file2check;
            try2save(rscriptFile);
        else
            
            prompt = 'Select ''RScript'' program which is required to run R scripts and is installed with a standard, separate, R installation.';
            uiwait(msgbox(prompt,'modal'));
            rscriptFile = uigetfullfile(filterFile,prompt,file2check);
            try2save(rscriptFile);
        end
    end
end

function didSave = try2save(rscriptFile)
    if(exist(rscriptFile,'file'))
        save(rscriptFile,'file2check','-ascii');
        didSave = true;
    else
        didSave = false;
    end
end