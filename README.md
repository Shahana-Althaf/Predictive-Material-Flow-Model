# Predictive-Material-Flow-Models
DOI -- https://zenodo.org/badge/191383132.svg
Matlab codes for forecasting future sales and waste flows of products

The two models deal with two different categories of products: 
Mature Product Model -for products with abundant historic data.
Emerging Product Model- for products with limited adoption data.

The material flow models calculate product flows (inflows or sales, and waste flows) in units as well as mass (kg).
The waste flows are calculated by multiplying annual sales by product lifespan probability. 

Lifespan Distribution: The lifespan probability of products is assumed to follow a Weibull distribution function, generated based on the parameters provided by the user. 
The probability for a given range of lifespan is generated using the MATLAB function for cumulative distribution function for Weibull given as
P = cdf ('Weibull', X, a, b) where X is the range of lifespan (minimum to maximum lifespan of the product), the probability of which is to be calculated, a is the shape parameter and b is the scale parameter.
The models take minimum, maximum, mean and std deviation of lifespan, as inputs generate the Weibull cdf using the rood2d function. 

Sales Distribution: The sales distribution is assumed to follow a logistic curve with decay. 
The model generates a logistic curve for sales of products from the inputs provided by the user. 
The mature product model takes all logistic parameters such as growth rate, sigmoid midpoint, peak sales, decay rate and decay midpoint as inputs to generate the logistic sales curve, 
the emerging product model generates the sales curve from just the year of market entry and peak sales. 

The models take a .csv file as the input sheet. Samples files for model inputs are uploaded with the codes.  
Input sheet (.csv files)  for input sheet for mature model should be named ‘User_Input_MatureProducts’ and 
that of emerging model should be named ‘User_Input_EmergingProducts’. Data dictionary for the input sheets for the models are given below.
Input sheet for mature product model has 16 columns while emerging product model has 11 columns. 
The first 6 columns of the input sheet for both models are the same.

Data Dictionary for Input sheets.

Columns 1 to 6 (both models) is to provide basic details about the products.

Column 1: Product ID = Assign a number to each product. (Increment the number by one, when each product is entered, the maximum number in Product ID column indicates the number of products to be analyzed.

Column 2: Product_Name =Enter Product Type

Column 3: Category= Enter a number to indicate product category

Column 4: Mass= Enter average mass of the product in kg.

Column 5: Sales_Start_Year or Year_of_Market_Entry = Enter the year in which the product was first sold in United states.

Column 6: Target Year= Enter the year till when the outflow calculations are to be performed.

Column 7: Peak_Sales_Units = Maximum Sales 

Emerging Product Model (Columns 8 to 11) 

Column 8: Minimum_Lifespan= Enter any whole number other than zero (default= 1)

Column 9: Maximum_Lifespan= Enter any whole number other than zero ( default= 10)

Column 10: Mean_Lifespan = Enter average product lifespan

Column 11: Std_dev_Lifespan = Enter standard deviation of product lifespan

Mature Product Model (Columns 8 to 16) 

Column 8: Time_to_peak = Enter number of years to reach sales peak from year of market entry.

Column 9: Sales_growth_rate= Enter sales growth rate generated through logistic curve fitting of historic adoption data.

Column 10: Sales_growth_sigmoid_midpoint= Enter sales growth midpoint generated through logistic curve fitting of historic adoption data.

Column 11: Sales_decay_rate= Enter sales decay rate generated through logistic curve fitting of historic adoption data.

Column 12: Sales_decay _sigmoid_midpoint= Enter sales decay midpoint generated through logistic curve fitting of historic adoption data.

Column 13: Minimum_Lifespan= Enter any whole number other than zero (default= 1)

Column 14: Maximum_Lifespan= Enter any whole number other than zero (default= 10)

Column 15: Mean_Lifespan = Enter average product lifespan

Column 16: Std_dev_Lifespan = Enter standard deviation of product lifespan

