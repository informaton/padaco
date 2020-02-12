%> @file restartDlg
%> @brief A dialog that asks the user to confirm they want to restart
%> the padaco program.  
% Hyatt Moore IV, 3/24/2016
% --------------------------------------------------------------------
function restartDlg(varargin)
choice = questdlg({'Please confirm that you want to ';' ';
                   'restart the Padaco program '},...
               'Warning', ...
	'Restart','Cancel','Cancel');

% Handle response
if(strcmpi(choice,'Restart'))
    restart();    
end
