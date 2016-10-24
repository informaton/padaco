%> @brief Removes all contents of pathname, but leaves pathname present.
function deletePathContents(pathname)
   narginchk(1,1);
   
   if(isdir(pathname))
       [~, fullSubPaths] = getPathnames(pathname);
       
       for f=1:numel(fullSubPaths)
           rmdir(fullSubPaths{f},'s');
       end
       delete(fullfile(pathname,'*'));
   else
       throw(MException('PADACO:InvalidPathname','Invalid pathname!'));
   end
           
       
       
end