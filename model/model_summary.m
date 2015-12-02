%> @brief Calculates mean values for field(s) and groupings (optional) listed.
%> @param Name of the database field to summarize.  Cells of strings are
%> convereted to multiple select statements.  
%> 'all' equates to '*'
%> @param Optional field to group by.  Must be a field name (not cell
%> string) or empty. 
function model_summary(fieldNames,  groupBy)

if(nargin<2)
    groupBy = [];
    if(nargin<1 || isempty(fieldNames))
        fieldNames = 'all';
    end
end

    
if(isempty(groupBy))
    groupBySql = '';
else
    groupBySql = sprintf('GROUP BY %s',groupBy);
end

db=CLASS_database_goals();

if(ischar(fieldNames) && strcmpi(fieldNames,'all'))
    q=mym('describe {S}',db.tableNames.subjectInfo);
    fieldNames = q.Field;
end

if(iscellstr(fieldNames))
    selectionSql = db.cellstr2statcsv(fieldNames);
else
    selectionSql = fieldNames;
end

db.open(); 

q=mym('SELECT {S} FROM {S} {S}',selectionSql,db.tableNames.subjectInfo,groupBySql);


end