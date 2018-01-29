% Helper function to open directory on Windows and Mac operating systems.
% Requires a valid input pathname for its argument.

% @author Hyatt Moore IV
function openDirectory(directory)
    if(isempty(directory) || ~exist(directory,'dir'))
        directory = pwd;
    end
    if(ispc)
        dos(sprintf('explorer.exe %s',directory));
    elseif(ismac)
        system(sprintf('open -R "%s"',directory));
    end
end