%> @brief Returns the path name associated with the input path key for the
%> current operating system.
%> @param pathKey String specifying the type of path to find.  Can be:
%> - @c doc - Return documents path
%> - @c user Return user path
%> - @c app Return applications path
%> @retval pathname String of the full pathname found, or empty if path was
%> not found or pathKey is invalid.
function pathname = findpath(pathKey)
    narginchk(1,1);
    
    switch(lower(pathKey))
        case {'home'}
            if(ispc)
                pathname = getenv('USERPROFILE');                                
            else
                pathname = getenv('HOME');                
                if(isempty(pathname))
                    pathname = '~/';
                end                
            end
            
        case {'document','docs','documents'}
            if(ispc)
                % Could try this also..
                %   pathname = fullfile(findpath('home'),'My Documents');
                
                
                % Sorry :(  
                % Finding a 'My Documents' equivalent is not possible for
                % all Windows version from registry queries.
                % So, rather than write some .NET code, I'm just going to
                % throw back the personal path of the user.
                pathname = winqueryreg('HKEY_CURRENT_USER',...
                    ['Software\Microsoft\Windows\CurrentVersion\' ...
                    'Explorer\Shell Folders'],'Personal');
            else
                pathname = fullfile(findpath('home'),'Documents');
            end
            
        case {'user','users'}
            if(ispc)
                pathname = winqueryreg('HKEY_CURRENT_USER',...
                    ['Software\Microsoft\Windows\CurrentVersion\' ...
                    'Explorer\Shell Folders'],'Personal');
            else
                pathname = '~/';
            end
        case {'applications','apps','app','application'}
            if(ispc)
                % This is hidden from the user
                pathname = winqueryreg('HKEY_CURRENT_USER',...
                    ['Software\Microsoft\Windows\CurrentVersion\' ...
                    'Explorer\Shell Folders'],'Local AppData');
            elseif(ispc)
                pathname = '/Applications';
            else
                pathname = '/usr/local/bin';
            end
        otherwise
            throw(MException('PADACO:InvalidInput','Invalid key submitted for findpath'));
    end
end
