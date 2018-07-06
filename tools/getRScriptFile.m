% Locates the R program to be used in executing R script files.
function rscriptFile = getRScriptFile(file2check)
    curPath = fileparts(mfilename('fullpath'));
    settingsFile = fullfile(curPath,'rscript.path');
    
    if(nargin<1 || isempty(file2check))
        file2check = '';
        if(exist(settingsFile,'file'))
            fid = fopen(settingsFile,'r');
            if(fid>1)
                try
                    file2check = fgetl(fid);
                catch me
                    file2check = '';
                end
                fclose(fid);
            end
        end
    end

    if(exist(file2check,'file'))
        rscriptFile = file2check;
    else
        if(ismac)
            file2check = '/usr/local/bin/RScript';
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
            try2save(rscriptFile, settingsFile);
        else
            
            prompt = 'Select ''RScript'' program which is required to run R scripts and is installed with a standard, separate, R installation.';
            uiwait(msgbox(prompt,'modal'));
            rscriptFile = uigetfullfile(filterFile,prompt,file2check);
            try2save(rscriptFile, settingsFile);
        end
    end
end

function didSave = try2save(rscriptFilename, saveFilename)
    didSave = false;
    if(exist(rscriptFilename,'file') && ~exist(rscriptFilename,'dir') && nargin>1 && ~isempty(saveFilename))
        
        fid = fopen(saveFilename,'w+');
        if(fid>1)
            fprintf(fid,rscriptFilename);
            fclose(fid);
            didSave = true;
        end
    end
end