%> @brief Place ',' in between cell string entries.  Useful for mysql
%> select quereies.
%> string = cellstr2csv(cellString)
%> @param Cell string of fields to select.
%> @retval String
%> @note
%> example:
%>    cellString = {'A0001';
%>                  'A0003';
%>                  'A0008'};
%>
%>    selectStr = cell2csv(cellString)
%>
%>    ans =
%>               A0001,A0003,A0008
%>
%> @authoer Hyatt Moore, IV (August 4, 2014)
function selectStr = cell2csv(cellOfKeys)
    if(isempty(cellOfKeys))
        selectStr = '';
    else
        [r,c] = size(cellOfKeys);
        if(r>c)
            selectStr = cell2mat(strcat(cellOfKeys,',')');
        else
            selectStr = cell2mat(strcat(cellOfKeys',','));
        end
        %remove the trailing ','
        selectStr(end) = [];
        
    end
end