
%% Mature Product Predictive Model

clear;
%% Step1: Read User input spreadsheet

%User Input - specify input as a CSV format
input_sheet = readtable('User_Input_MatureProducts.csv');

%creating an array to store number of products entered by the user
prod_list = unique(input_sheet.ProductID);

C =[];
%input parameters are initial sales units, time to peak, average annual growth rate
input_sheet.Sales_Starting_Pt= input_sheet.Start_Year_of_Sales-1;
input_sheet.Peak_Sales_Year=input_sheet.Start_Year_of_Sales+input_sheet.Time_to_peak; 
input_sheet.Total_yrs_to_sales_peak=input_sheet.Time_to_peak;
input_sheet.Total_yrs_to_target_year=input_sheet.Target_Year-input_sheet.Start_Year_of_Sales;


%for all products i
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
b1=input_sheet.Total_yrs_to_sales_peak(i);


ksol11=input_sheet.Sales_growth_rate(i);% growth rate
smSol11=input_sheet.Sales_growth_sigmoid_midpoint(i);%growth midpoint
t_till_decay_sales=1:1:input_sheet.Total_yrs_to_sales_peak(i)+1;% growth years
tpeak_sales=input_sheet.Total_yrs_to_sales_peak(i)+1;%peak year

%Sales growth till peak
S_growth= a./(1+exp(-(ksol11).*(t_till_decay_sales-(smSol11)))); %logistic growth equation

Decay_Sales(i)= input_sheet.Total_yrs_to_target_year(i)-input_sheet.Total_yrs_to_sales_peak(i);%decay starts right after peak year
 
% check if target year includes decay period
if Decay_Sales(i)<=0
    Sales=S_growth(1:input_sheet.Total_yrs_to_target_year(i)+1);    
else
    
%Sales decay till peak
ksol22=input_sheet.Sales_decay_rate(i);%decay rate
smSol22=input_sheet.Sales_decay_sigmoid_midpoint(i)+tpeak_sales;% decay midpoint
t_decay_start=tpeak_sales+1:1:input_sheet.Total_yrs_to_target_year(i)+1;% decay start year
S_decay= a./(1+exp(-(-ksol22).*(t_decay_start-(smSol22))));% logistic decay equation

%Concatenating sales growth and sales decay curve to generate full sales
%curve till target year

Sales=[S_growth,S_decay];
end

%Remove Negatives
tolerance=0;
%check col to see which elements are less than tolerance
ids_switch=logical(Sales < tolerance);
%convert them to zero
S(ids_switch)=0;

%% Concatenate arrays to convert to a table
Year=input_sheet.Start_Year_of_Sales(i):input_sheet.Target_Year(i);

C1= cat(2,Year',ProdID',Category1',Avg_mass',Sales');

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
X =  input_sheet.Minimum_Lifespan(i):input_sheet.Maximum_Lifespan(i);%X is range of lifespan, min to max 
x0 = [1 1];

options = optimset('Display','iter');
%calculate weibull shape (x(1)) and scale parameters (x(2)) from mean and std deviation of lifespan using fucntion root2d
x= fsolve(@(x0) root2d(x0,input_sheet.Mean_Lifespan(i),input_sheet.Std_dev_Lifespan),x0,options);
% Generate weibull cdf
P = cdf('Weibull',X,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
      
%% Step 5: Calculate Product wasteflows in units based on sales and lifespan distributions

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
   'VariableNames',{'Product_wasteflow_units' 'ProductID' 'Year'});


%Join the table with stock and sales with the table with top down outflow 
Inflow_sheet = outerjoin(prod_sheet,Wasteflow_sheet);


%Remove recurring columns in the table
Inflow_sheet(:,end-1:end)=[];


%% Step 6: Calculate product mass flows by multiplying sales units and wasteflow units by average product mass

Inflow_sheet.Product_wasteflow_totalmass=(Inflow_sheet.Product_wasteflow_units).*...
  (Inflow_sheet.Average_Mass);
%Convert Nans due to year mismatch to zero
Inflow_sheet.Product_wasteflow_units(isnan(Inflow_sheet.Product_wasteflow_units)) = 0;%% converting Nans to zero
Inflow_sheet.Total_Sales_mass = ((Inflow_sheet.Sales_units).*(Inflow_sheet.Average_Mass));

% Renaming columns in inflowsheet for clarity
 Inflow_sheet.Properties.VariableNames{'Year_prod_sheet'} ='Year';
 Inflow_sheet.Properties.VariableNames{'ProductID_prod_sheet'} ='ProductID';
 
%% Step 7:  Save the MFA model output as an excel file
writetable(Inflow_sheet,'MatureProduct_MFA_Outputsheet.xls');% This excel sheet can be intergrated with product bill of materials to generate material flows
%% End
