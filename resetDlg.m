% --------------------------------------------------------------------
function resetDlg(defaultsFilename)
% Construct a questdlg with three options
choice = questdlg({'Click OK to reset setting parameters.';' ';
                   ' This may be necessary when copying ';
                   ' the software to a new computer or when  '
                   ' a parameter file becomes corrupted.'; ' '},...
               'Set Defaults', ...
	'OK','Cancel','Cancel');

% Handle response
if(strncmp(choice,'OK',2))
    if(exist(defaultsFilename,'file'))
        delete(defaultsFilename);
    else
        warndlg(sprintf('The default parameter file (%s) does not exist!',defaultsFilename));  
    end
    restart();
end
