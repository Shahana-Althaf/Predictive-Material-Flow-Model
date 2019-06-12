
%% Predictive MFA model for emerging products with limited adoption data

clear;
%% Step 1: Read User input spreadsheet

%User Input - specify input as a CSV format
input_sheet = readtable('User_Input_EmergingProducts.csv');

%creating an array to store number of products entered by the user
prod_list = unique(input_sheet.ProductID);


C =[];
%input parameters are initial sales units, time to peak, growth rate
input_sheet.Sales_Starting_Pt= input_sheet.Year_of_Marketentry-1;
%generating time to peak based on temporal trends
input_sheet.Time_to_peak= round((1.287*(10^32))*exp(-0.03579*(input_sheet.Year_of_Marketentry)));
input_sheet.Peak_Sales_Year=input_sheet.Year_of_Marketentry+input_sheet.Time_to_peak; 
input_sheet.Total_yrs_to_sales_peak=input_sheet.Time_to_peak;
input_sheet.Total_yrs_to_target_year=input_sheet.Target_Year-input_sheet.Year_of_Marketentry;


for i=prod_list'

%% Step 2: Create product id , name, mass columns from user input

ProdID=[];
ProdID(1:input_sheet.Total_yrs_to_target_year(i)+1) = i;
 
Category1=[];
Category1(1:input_sheet.Total_yrs_to_target_year(i)+1)=input_sheet.Category(i);
Avg_mass=[];
Avg_mass(1:input_sheet.Total_yrs_to_target_year(i)+1) = input_sheet.Mass(i);


%% Step 3: Generate Sales Curve which is assumed to be a logistic curve with decay
%% Logistic curve for sales

a=input_sheet.Peak_Sales_Units(i);

%Generating Sales Growth Curve
deltaT=(5.088*(10^(38)))*exp((-0.04362)*input_sheet.Year_of_Marketentry(i)); % delta T based on temporal trend equation
kSol11=(log(81))/deltaT;% growth rate calculated as delta T (ln(81)/delta T)
smSol11=round((1.253*(10^26))*exp((-0.02904)*input_sheet.Year_of_Marketentry(i)));% growth sigmoid midpoint based on temporal trend equation

t_till_decay_sales=1:1:input_sheet.Total_yrs_to_sales_peak(i)+1; %growth period
tpeak_sales=input_sheet.Total_yrs_to_sales_peak(i)+1;% peak sales year

%%%%Sales growth curve based on logistic equation
S_growth= a./(1+exp(-(kSol11).*(t_till_decay_sales-(smSol11))));

DecayTest_Sales(i)= input_sheet.Total_yrs_to_target_year(i)-input_sheet.Total_yrs_to_sales_peak(i);
 %Checking if the target year includes decay period
if DecayTest_Sales(i)<=0
    Sales=S_growth(1:input_sheet.Total_yrs_to_target_year(i)+1);    
else
 
%Generating Sales Decay Curve
kSol22=kSol11;% Sales Decay rate assumed to be same as growth rate
smSol22=round(tpeak_sales+(tpeak_sales-smSol11));% Decay sigmoid midpoint

t_decay_start=tpeak_sales+1:1:input_sheet.Total_yrs_to_target_year(i)+1;

%%%%Sales decay curve based on logistic equation
S_decay= a./(1+exp(-(-kSol22).*(t_decay_start-(smSol22))));

%Concatenating sales growth and decay to generate complete sales curve
Sales=[S_growth,S_decay];
end

%Remove Negatives
tolerance=0;
%check col to see which elements are less than tolerance
ids_switch=logical(Sales < tolerance);
%convert them to zero
S(ids_switch)=0;

%% Concatenate arrays to convert to a table
yr=input_sheet.Year_of_Marketentry(i):input_sheet.Target_Year(i);

C1= cat(2,yr',ProdID',Category1',Avg_mass',Sales');

C= vertcat(C,C1); % C array has all the arrays concatenated together

end

%% Converting Year, Sales and Stock arrays to columns in a table with headers

prod_sheet  = table(C(:,1),C(:,2),C(:,3),C(:,4),C(:,5),...
   'VariableNames',{'Year' 'ProductID' 'Category' 'Average_Mass' 'Sales_units'});

%% Start Material Flow Process (Sales-Lifespan MFA)

COL_YR = [min(prod_sheet.Year):1:max(prod_sheet.Year)]';
COL_TOP_DOWN_OUTFLOW = [];
x=[];

for i=prod_list'
    
%% Step 4: Generate probability distribution for product lifespan (Weibull Distribution)

X =  input_sheet.Minimum_Lifespan(i):input_sheet.Maximum_Lifespan(i);%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
% Calculating weibull scale and shape parameters from mean and std
% deviation of product lifespan
x= fsolve(@(x0) root2d(x0,input_sheet.Mean_Lifespan(i),input_sheet.Std_dev_Lifespan),x0,options);
% Generating weibull cumulative distribution function 
P = cdf('Weibull',X,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
 
%% Step 5: Calculate product unit waste flows by multiplying sales by product lifespan probability distribution
 
        start_yr = min(prod_sheet(prod_sheet.ProductID==i,:).Year);
        end_yr = max(prod_sheet(prod_sheet.ProductID==i,:).Year);
        add_this_yr_topdownOF=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_outflow_withP =0;
         for m = 1:length(P)
        Yr_N= Y-X(m);
        rows = (prod_sheet.ProductID==i&prod_sheet.Year==Yr_N);
        vars = {'Sales_units'};
        topdown_outflow_sales = prod_sheet{rows,vars};
        if isempty(topdown_outflow_sales)
          topdown_outflow_sales =0;
        end
        if m==1
        topdown_outflow_withP = topdown_outflow_withP+topdown_outflow_sales*(P(m));
        else
            topdown_outflow_withP = topdown_outflow_withP+(topdown_outflow_sales*(P(m)-P(m-1)));
        end
         end
        add_this_yr_topdownOF = [add_this_yr_topdownOF;topdown_outflow_withP,i,Y];
        end
    COL_TOP_DOWN_OUTFLOW  = [COL_TOP_DOWN_OUTFLOW ;add_this_yr_topdownOF];
end


%Converting array to table with headers
Wasteflow_sheet = table(COL_TOP_DOWN_OUTFLOW(:,1),COL_TOP_DOWN_OUTFLOW(:,2),COL_TOP_DOWN_OUTFLOW(:,3),...
   'VariableNames',{'Wasteflow_Units' 'ProductID' 'Year'});

%Join the table with stock and sales with the table with top down outflow 
Inflow_sheet = outerjoin(prod_sheet,Wasteflow_sheet);


%Remove recurring columns in the table
Inflow_sheet(:,end-1:end)=[];

%% Step 6: Calculate product mass flows by multiplying sales units and wasteflow units by average product mass
%Calculate wasteflow mass
Inflow_sheet.Total_Wasteflow_mass=(Inflow_sheet.Wasteflow_Units).*...
  (Inflow_sheet.Average_Mass);
%Convert Nans due to year mismatch to zero
Inflow_sheet.Wasteflow_Units(isnan(Inflow_sheet.Wasteflow_Units)) = 0;%% converting Nans to zero
Inflow_sheet.Total_Sales_mass=(Inflow_sheet.Sales_units).*...
  (Inflow_sheet.Average_Mass);

% Renaming columns in inflowsheet for clarity
 Inflow_sheet.Properties.VariableNames{'Year_prod_sheet'} ='Year';
 Inflow_sheet.Properties.VariableNames{'ProductID_prod_sheet'} ='ProductID';
 
%% Step 7:Save the MFA model output table as an excel file
writetable(Inflow_sheet,'EmergingProduct_MFAmodel_Outputsheet.xls');% This excel sheet can be incorporated with product bill of materials to calculate material flows

%% END

