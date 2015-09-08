% Model:  Logistic regression analysis for GOALS data via geeqbox.
% Type:   Simple
% Description:  Uses subjectinfo_t table from goals_db database.

clear all;

db=CLASS_database_goals();
db.open();

availableCovariates = {
    'bmi'
    'height_cm'
    'weight_kilo'
    'bp_map'
    'bp_pulse'
    'skin_mm'
    'waist_cm'
    '(sex=1) AS male' %'sex' % ENUM (male = ''1'',female = ''2'', unknown/unset = ''?'')
    'bmi_zscore'
    'chol_hdl'
    'chol_total'
    'triglyceride'
    'glucose'
    'insulin'
    'hs_crp'
    'hba1c'
    'alt'
    'chol_vldl'
    'chol_ldl'
    'age'
    'bp_sys'
    'bp_dia'
    'depression_cdi'
    'bmi_percent'
    'bp_sys_pct'
    'bp_dia_pct'};




%% Identify phenotype - dependent variable.
phenotypeSelection = 'bmiz+'; %logit example
phenotypeSelection = 'bmi_zscore'; %linear example

unhandledPhenotype = false;


covariateOfInterestInd = 1; %by default, pick the first covariate as the one of interest in the covariates_sql listing.
switch(phenotypeSelection)

    case 'bmiz+'
        groupName = 'BMI Z-score(+)';
        phenotype_sql = ' bmi_zscore>=2';
        control_sql = ' bmi_zscore<2 ';
        covariates_sql =     'age, (sex=1) AS male';
        logitModel = true;

    otherwise
        
        % linear modeling...
        matchInd = strcmpi(phenotypeSelection,availableCovariates);
        if(~isempty(matchInd))
            phenotype_sql =phenotypeSelection;
            groupName = phenotypeSelection;
            covariates = availableCovariates;
            covariates(matchInd) = [];  %Kick it out of the covariates.
            
            %             covariates_sql = cell2mat(strcat(',',covariates)');
            %             covariates_sql(1) = [];
            
            
            covariates_sql = cell2mat(strcat(covariates,',')');
            covariates_sql(end)=[];
            logitModel = false;

            
            %             covariates_sql = makeSelectKeysString(covariates);
            
        else
            fprintf('This case %s is not handled\n',phenotypeSelection);
            unhandledPhenotype = true;
        end
end


% Time field is the what we use assume our repeated observations are
% correlated by.
timeField = 'visitnum'; % {'age','visitnum'};


% Place additional requirements here to filter subjects
% [Default] is to take subjects from first visit only.
visitNumber = 1;
subjectTableName = 'subjectinfo_t';
subjectID = 'kidid';

if(logitModel)
    minimumRequirementsQuery = sprintf('SELECT %s AS subjectID FROM %s WHERE visitnum=%u AND ((%s) OR (%s))',subjectID,subjectTableName,visitNumber,phenotype_sql,control_sql);
else
    minimumRequirementsQuery = sprintf('SELECT %s AS subjectID FROM %s WHERE visitnum=%u AND ((%s) IS NOT NULL)',subjectID,subjectTableName,visitNumber,phenotype_sql);
end


if(~unhandledPhenotype)
    
    % Require that we have at least X days of recording for our subjects.
    qSubjects = mym(minimumRequirementsQuery);
    subjectIDInStr = makeWhereInString(qSubjects.subjectID,'numeric');
    
    % Establish my queries based on subjects meeting minimum requirements
    % for the model.
    modelQuery = sprintf('SELECT %s AS subjectID, %s AS dependentVariable,  %s AS timeVariable, %s FROM %s WHERE visitnum=%u AND %s IN %s ORDER BY %s',subjectID,phenotype_sql, timeField, covariates_sql, subjectTableName,visitNumber,subjectID,subjectIDInStr,subjectID);
    
    % Get the phenotype/dependent variable, and other parts.
    qModel = mym(modelQuery);
    
    % phenotype
    Y = qModel.dependentVariable;
    n1 = sum(Y==1);
    n0 = sum(Y==0);
    n = numel(Y);
    
    % Verify counts are correct - sanity check
    fprintf(1,'%s:\tCase (n=%u) vs Control (n=%u)\n',groupName,n1,n0);
    
    % repeated measure correlate
    time = qModel.timeVariable;
    
    %     % patid - do a trick here
    [uniquePatid,~,id] = unique(qModel.subjectID); %get the unique, numeric identifiers for each patid which is a cell array of chars
    %
    %     % Either way works.
    %     %  Option 1:
    %     %     patidFields = makeSelectKeysString(cellstr(num2str(uniquePatid)));
    %
    %     %  Option 2:
    %     kididFields = makeWhereInString(uniquePatid,'numeric');
    %     kididFields = kididFields(2:end-1);  %remove parenthesis
    
    % shrink to covariates only (i.e. predictors)
    independentVariables = rmfield(qModel,{'timeVariable','subjectID','dependentVariable'});
    
    X = [cell2mat(struct2cell(independentVariables)'), ones(n,1)];
    
    glmfit_const = 'on';
    geeCovariates = [fieldnames(independentVariables);'const']';    
    numCovariates = numel(geeCovariates); % or size(X,2);
    
    
    % This is a necessary check to make sure I am not including bad
    % data.
    dataSet = [id,Y,time,X];
    exclude_ind=sum(isnan(dataSet),2);
    dataSet(exclude_ind~=0,:)=[];
    
    try
        if(logitModel)
            [BetaAll, alpha, results] = gee(dataSet(:,1),dataSet(:,2),dataSet(:,3), dataSet(:,4:end),'b','markov',geeCovariates);%,geeCovariates);
        else
            [BetaAll, alpha, results] = qls(dataSet(:,1),dataSet(:,2),dataSet(:,3),dataSet(:,4:end),'n','markov',geeCovariates);
        end
        %         [BetaAll, alpha, results] = geeSilent(dataSet(:,1),dataSet(:,2),dataSet(:,3), dataSet(:,4:end),'b','markov');%,geeCovariates);
    catch me
        showME(me);
        if(logitModel)
            [BetaAll, alpha, results] = gee(dataSet(:,1),dataSet(:,2),dataSet(:,3), dataSet(:,4:end),'b','un',geeCovariates);
        else
            [BetaAll, alpha, results] = qls(dataSet(:,1),dataSet(:,2),dataSet(:,3),dataSet(:,4:end),'n','un',geeCovariates);
        end

        
        
    end
    
    %gee output is given with statistics in columns for each covariate row
    se_ind = 3;
    p_ind = 5;
    ci_alpha = 0.95;
    
    ConfidenceIntervals = [-norminv((ci_alpha+1)/2), norminv((ci_alpha+1)/2)]*results.robust{covariateOfInterestInd+2,se_ind}+exp(BetaAll(covariateOfInterestInd));
    
    p=results.robust{covariateOfInterestInd+2,p_ind};
    numDec = log10(p);
    if(numDec<-3)
        %pfmt = '%1.0e';
        pstr = sprintf('<1e-%i',abs(fix(numDec)));
    else
        pstr = sprintf('%0.3f',p);
    end
    
    outputStr = sprintf('%s\t%0.2f\t%0.3f\t(%0.2f, %0.2f)\t%s\n','covariateOfInterest',BetaAll(covariateOfInterestInd),exp(BetaAll(covariateOfInterestInd)),ConfidenceIntervals,pstr);
    %                 fprintf(chromoFid2,'rs%u\t%c\t%0.2f\t%0.3f\t(%0.2f, %0.2f)\t%s\n',refSNP(snp_ind),minor_allele{snp_ind},BetaAll(refSNPCovariateInd),exp(BetaAll(refSNPCovariateInd)),ConfidenceIntervals,pstr);
    fprintf(1,outputStr);

else
    fprintf(1,'Case not handled!\n');
end

db.close();
