%> @brief Calculates mean values by group.
%> @param Fields to group by.  Cell string.
%> @param Name of the database field to summarize.  Cells of strings are
%> convereted to multiple select statements.  
%> 'all' equates to '*'
%> @note Output is a tab-delimited table with summary values.
% groupSQLs = {'(sex=1)','Male';
%     '(sex=2)','Female'};
% groupSQLs = {'(sex=1)','Male';
%     '(sex=2)','Female';
%     '(sex=1) OR (sex=2)','All'};

%     groupNames = groupSQLs(:,1);
%     groupNames= groupSQLs(:,2);
%     groupSQLs= groupSQLs(:,1);

% table_summary(groupSQLs);
function table_summary(groupSQLs,groupNames,fieldNames,primaryKeyFields)
    
    if(nargin<3 || strcmpi(fieldNames,'all'))
        fieldNames = '*';
    end

    if(nargin<4)
        primaryKeyFields = '';
    end
    
    if(nargin<1)
        groupCells = {'(sex=1)','Male';
            '(sex=2)','Female';
            '(sex=1) OR (sex=2)','All'};
        
        groupSQLs= groupCells(:,1);
        groupNames = groupCells(:,2);
        primaryKeyFields = {'kidid','visitnum'};

    end
%     if(isempty(groupBy))
%         groupBySql = '';
%     else
%         groupBySql = sprintf('GROUP BY %s',groupBy);
%     end

    
    numGroups = numel(groupNames);
    
    
    %% for comparisons
    doTtest = true;
    if(doTtest)
        t_comparison_indices = [1,2];  %which indices to compare for t-test, etc.
    end
    
    doANOVA = false; %will show ANOVA value if true
    if(doANOVA)
        anova_indices = [1,2,3];
    end   
    
    db=CLASS_database_goals();
    
    if(iscellstr(fieldNames))
        selectionSql = db.cellstr2statcsv(fieldNames);
    else
        selectionSql = fieldNames;
    end    
    
    db.open();
    
    
    fprintf(1,'\n');
    
    columnData = cell(numGroups,1);
    columnSummary = columnData;
    

    groupCount = zeros(numGroups,1);
    for g=1:numGroups
        groupWhereSQL = groupSQLs{g};
        q1 = mym('SELECT count(*) AS groupCount FROM {S} WHERE {S}',db.tableNames.subjectInfo,groupWhereSQL);
        groupCount(g) = q1.groupCount;
        
%         fprintf(1,'\t%s (n=%u)',groupNames{g},groupCount(g));

        
        q2 = mym('SELECT {S} FROM {S} WHERE {S}',selectionSql,db.tableNames.subjectInfo,groupWhereSQL);
        columnSummary{g} = summarizeStruct(q2);
        

    end
    
    % Place this here - and not in the loop above - because sometimes
    % errors above are caught but still show output to the console which
    % makes the final table look bad.
    for g=1:numGroups
        fprintf(1,'\t%s (n=%u)',groupNames{g},groupCount(g));
    end
    
    numColumns = numGroups+1;
    
    
    
    %% for comparisons
    if(doTtest)
        numComparisons = size(t_comparison_indices,1);
        numColumns = numColumns+numComparisons;
        for c_ind = 1:numComparisons
            fprintf(1,'\t%s vs %s',groupNames{t_comparison_indices(c_ind,1)},groupNames{t_comparison_indices(c_ind,2)});
        end
    end
    
    if(doANOVA)
        numColumns = numColumns+1;
        if(~isempty(anova_indices))
            fprintf(1,'\tp (ANOVA)');
        end
    end
    
    %output to console as a table now
    rowNames = fieldnames(columnSummary{1});
    numRows = numel(rowNames);
    
    fprintf(1,'\n');

    
    
    for row = 1:numRows
        demoName = rowNames{row};
        
        if(~any(strcmpi(demoName,primaryKeyFields)))
            
            demographicStr = demoName;
            
            if(strcmpi(demoName,'age'))
                fprintf('Demographics\n');
            elseif(strcmpi(demoName,'bmi'))
                fprintf('Clinical Data\n');
            end
            
            fprintf(1,'%s',demographicStr);
            for col=1:numGroups
                fprintf('\t%s',columnSummary{col}.(demoName).string);
            end
            
            if(doTtest)
                
                try
                    for c_ind = 1:numComparisons
                        compare_ind = t_comparison_indices(c_ind,:); %should only be two columns
                        this_ind = compare_ind(1);
                        other_ind = compare_ind(2);
                        
                        if(isempty(columnSummary{this_ind}.(demoName).var)) %do a contingency
                            %contingence vector should be [controls below, controls above, rls below, rls above]
                            contingency = [columnSummary{other_ind}.(demoName).n_below,columnSummary{other_ind}.(demoName).n_above,columnSummary{this_ind}.(demoName).n_below,columnSummary{this_ind}.(demoName).n_above];
                            [chi_square,p_value,odds_ratio] = contingency2chi(contingency);
                            
                            if(isempty(chi_square)||isempty(p_value)||isnan(chi_square)||isnan(p_value))
                                %                     fprintf(1,'\tX%c=N/A p=N/A',178);
                                fprintf(1,'\tOR=N/A p=N/A');
                            else %?
                                numDec = log10(p_value);
                                if(numDec<-3)
                                    %pfmt = '%1.0e';
                                    p_str = sprintf('p<1e-%i',abs(fix(numDec)));
                                    
                                else
                                    p_str = sprintf('p=%0.3f',p_value);
                                end
                                
                                %                     fprintf(1,'\tX%c=%0.2f OR=%0.2f %s',178,chi_square,odds_ratio(3),p_str);
                                fprintf(1,'\tOR=%0.2f %s',odds_ratio(3),p_str);
                            end
                        else
                            
                            this_mx = columnSummary{this_ind}.(demoName).mx;
                            this_var = columnSummary{this_ind}.(demoName).var;
                            this_n = columnSummary{this_ind}.(demoName).n;
                            
                            other_mx = columnSummary{other_ind}.(demoName).mx;
                            other_var = columnSummary{other_ind}.(demoName).var;
                            other_n = columnSummary{other_ind}.(demoName).n;
                            
                            t_value = (this_mx-other_mx)/sqrt(this_var/this_n+other_var/other_n);
                            dof = other_n+this_n-2;
                            p_value = (1-cdf('t',abs(t_value),dof))*2;  %make it two-tailed (2-tailed)
                            if(isempty(t_value)||isempty(p_value)||isnan(t_value)||isnan(p_value))
                                fprintf(1,'\tp=N/A');
                            else
                                numDec = log10(p_value);
                                if(numDec<-3)
                                    fprintf(1,'\tp<1e-%i',abs(fix(numDec)));
                                    
                                else
                                    fprintf(1,'\tp=%0.3f',p_value);
                                end
                                
                                
                            end
                        end
                    end
                catch me
                    showME(me);
                end
            end
            
            if(doANOVA)
                if(isempty(columnSummary{anova_indices(1)}.(demoName).var)) %do a contingency
                    [chi_square, p_value] = chisquare_cellofstruct(columnSummary(anova_indices),demoName,{'n_above','n_below'});
                    
                    if(isempty(chi_square)||isempty(p_value)||isnan(chi_square)||isnan(p_value))
                        fprintf(1,'\tX%c=N/A p=N/A\t',178);
                    else %?
                        numDec = log10(p_value);
                        if(numDec<-3)
                            %pfmt = '%1.0e';
                            p_str = sprintf('p<1e-%i',abs(fix(numDec)));
                            
                        else
                            p_str = sprintf('p=%0.3f',p_value);
                        end
                        
                        fprintf(1,'\tX%c=%0.2f %s',178,chi_square,p_str);
                    end
                    
                else
                    p_value = anova1_cellofstruct(columnData(anova_indices),demoName);
                    numDec = log10(p_value);
                    if(numDec<-3)
                        fprintf(1,'\tp<1e-%i',abs(fix(numDec)));
                        
                    else
                        fprintf(1,'\tp=%0.3f',p_value);
                    end
                end
                
            end
            
            fprintf(1,'\n');
        end
    end
    mym('close');
    
    numRows = numRows+1; %+1 for top most tabel header row
    fprintf('\nTable has %u rows and %u columns\n',numRows,numColumns);


end


