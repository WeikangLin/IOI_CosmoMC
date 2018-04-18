%%%%%% A script for CosmoMC (after running getdist)
%%%%%% Calculate two-experiment IOIs for arbitary number of contraints
%%%%%% and in an arbitary parameter space
%%%%%% outputs in e.g., IOI_CMB.txt
%%%%%% Steps:
%%%%%% 0. Put all the .margestats and .corr files of the constraints of
%%%%%%    interest in one folder.
%%%%%% 1. Specify the constraint files directory that contains all 
%%%%%%    the .margestats and .corr files.
%%%%%% 2. Put the parameter names below 
%%%%%%    e.g., H0 parameterization in LCDM model:
%%%%%%      Params = {'omegabh2','omegam','H0','sigma8','ns','tau'};
%%%%%%    e.g., Theta parameterization in LCDM model:
%%%%%%      Params = {'omegabh2','omegach2','theta','logA','ns','tau'}; 

clear;
Params = {'omegabh2','omegach2','theta','logA','ns'};
constraint_filedir = './batch/';

Outfile = 'IOIs.txt';

margfiles = dir(fullfile(constraint_filedir, '*.margestats'));
Num_exp = length(margfiles);
if Num_exp<2
    ErrorMessage = sprintf(['Error: \n' ...
                'Atleast two constraints are required.\n']);
    disp(ErrorMessage);
    return        
end
ParamDim = length(Params);

exp_names = string(Num_exp);
for i=1:Num_exp
    exp_names(i) = erase(margfiles(i).name,'.margestats');
end

Message = sprintf([num2str(Num_exp) ' constraints, ' ...
    num2str(ParamDim) ' parameters.']);
disp(Message)



%%%%%% Find the common parameters
for i = 1:Num_exp
    fileID = fopen([constraint_filedir margfiles(i).name]);
    Marg_header = fgets(fileID);
    All_params = textscan(fileID,'%s %*[^\n]');
    if i==1
        Common_Params = All_params{1};
    end
    Common_Params = intersect(Common_Params, All_params{1});
end

Num_com_param = length(Common_Params);
txt = ['There are ' num2str(Num_com_param) ...
    ' common parameters (including derived),'...
    ' which are stored in variable Common_Params'];
disp(txt)



%%%%%% Extract mu and C from files
C = zeros(ParamDim,ParamDim,Num_exp);
mu = zeros(ParamDim,Num_exp);
sigma = zeros(ParamDim,Num_exp);
index = zeros(ParamDim,1);

delimiterIn = ' ';
headerlinesIn = 1;

for i = 1:Num_exp
    fileID = fopen([constraint_filedir margfiles(i).name]);
    Marg_header = fgets(fileID);
    Marg_header = fgets(fileID);
    Marg_header = fgets(fileID);
    meat = textscan(fileID,'%s %f %f %*[^\n]');
    for k = 1:ParamDim
        index(k) = 1;
        str=meat{1};
        NotFound = true;
        for ii=1:length(meat{1})
            if (strcmp(str{ii},Params{k}) == 1|strcmp(str{ii},[Params{k},'*']) == 1)
                index(k) = ii;
                NotFound = false;
            end
        end
        if NotFound == true
            ErrorMessage = sprintf(['Error: \n' ...
                Params{k} ' is not in experiment: ' exp_names{i}]);
            disp(ErrorMessage)
            return
        end
        mu(k,i) = meat{2}(index(k));    
        sigma(k,i) = meat{3}(index(k));   
    end
    fclose(fileID);
    
    Corr = importdata([constraint_filedir exp_names{i} '.corr']);
    offset = 0;
    for ii=1:length(Corr)
        if Corr(ii-offset,1)==0.0
           Corr(ii-offset,:) = [];
           Corr(:,ii-offset)  = [];
           offset = offset+1;
        end
    end   
    Corr_select = Corr([index],[index]);
    for n=1:ParamDim
        for m=1:ParamDim
            C(n,m,i) = sigma(n,i).*Corr_select(n,m)*sigma(m,i);
        end
    end
end


 
%%%%%% calculating all the two-experiment IOIs
IOI = zeros(Num_exp,Num_exp-1);
for i = 1: Num_exp
    for j = (i+1):Num_exp
        IOI(i,j) = 0.5*(mu(:,i)-mu(:,j))'*(C(:,:,i)+C(:,:,j))^-1*(mu(:,i)-mu(:,j));
        IOI(j,i) = IOI(i,j);
    end
end


%%%%%% Saving the results in a matrix for
fileID = fopen(Outfile,'w');
fprintf(fileID,'%18s',' ');
fprintf(fileID,'%18s',exp_names{:});
for i=1:Num_exp
    fprintf(fileID,'\n');
    fprintf(fileID,'%18s',exp_names{i});
    fprintf(fileID,'%18.2f',round(IOI(i,:),2));
end

FishingMessage = sprintf(['Finished: \n' ...
    'Two-experiment IOIs have been saved in ' Outfile '.\n']);
disp(FishingMessage)
 
fclose(fileID);