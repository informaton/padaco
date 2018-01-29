%> @function isormkdir(pathName)
%> @retval Boolean
%> @date 1/27/2018
%> @author Hyatt Moore IV
function doesExistOrWasMade = isormkdir(pathName)
    doesExistOrWasMade = exist(pathName,'dir');
    if(~doesExistOrWasMade)
        [doesExistOrWasMade,ERR_MESSAGE,MESSAGEID]=mkdir(pathName);
        if(~doesExistOrWasMade)
            fprintf(1,'The path "%s" was not found and could not be created.  The following error was given:\n\t%s',pathName,ERR_MESSAGE);
        end
    end
end