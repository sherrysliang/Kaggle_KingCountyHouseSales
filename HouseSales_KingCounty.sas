* Kaggle - House Sales in King County

* import file and display the first 10 observations;
proc import datafile = 'S:\kc_house_data.csv' out = house_all replace;
getnames = yes;
datarow = 2;
run;
proc print data = house_all (obs= 10);
run;

* check Zip Code of the data;
proc sql;
select distinct zipcode from house_all;
select count(distinct zipcode) from house_all;
run;

* select sample from the whole dataset, size = 2162;
proc surveyselect data=house_all out= house seed=2017 samprate=0.1 outall;
run;
data house (where = (Selected = 1)); set house;
run;
proc print data = house (obs= 10);
run;

* display summary information of the price data;
proc means mean min p1 p25 p50 p75 p99 max data=house;
var price bedrooms bathrooms sqft_living sqft_lot floors waterfront view condition grade 
sqft_above sqft_basement yr_built yr_renovated zipcode lat long sqft_living15 sqft_lot15;
run;

* distribution of price;
proc univariate normal;
var price;
histogram / normal(mu = est sigma = est);
title 'Distribution of Price';
run;

* log(price);
data house;
set house;
ln_price=log(price);
run;
proc print data= house (obs=10);
run;

proc univariate normal;
var ln_price;
histogram / normal(mu = est sigma = est);
title 'Distribution of ln_price';
run;

* drop some features (id, date) and create dummy variables (renovated_num, zipcode_num, basement) ;
data house;
set house (drop = selected id date);
renovated_num = 1;
if yr_renovated = 0 then renovated_num = 0;
zipcode_num = 1;
if zipcode <98101 then zipcode_num = 0;
basement = 1;
if sqft_basement = 0 then basement = 0;
run;
title;
proc print data = house (obs = 10);
run;

* create scatterplots y and quantitative variables ;
proc sgscatter data = house;
matrix ln_price bedrooms bathrooms sqft_living sqft_lot floors waterfront view condition 
grade sqft_above sqft_basement yr_built sqft_living15 sqft_lot15;
run;

proc corr;
var ln_price bedrooms bathrooms sqft_living sqft_lot floors waterfront view condition grade 
sqft_above sqft_basement basement yr_built renovated_num zipcode_num sqft_living15 sqft_lot15;
run;

* fit the full model, original categorical variables;
proc reg;
model ln_price = bedrooms bathrooms sqft_living sqft_lot floors waterfront view
condition grade sqft_above sqft_basement basement yr_built renovated_num 
zipcode_num sqft_living15 sqft_lot15/ stb vif;
run;
* R-Square 0.6659, Adj R-Sq 0.6633 (before removing outliers);


**************************** OUTLIERS *******************************;
* outliers and influential points;
proc means mean std stderr clm min p1 p25 p50 p75 p99 max data = house;
var bedrooms bathrooms sqft_living sqft_lot floors waterfront view condition 
grade sqft_above sqft_basement yr_built yr_renovated sqft_living15 sqft_lot15;
run;

* delete outliers with extreme X values;
data house;
set house;
if bedrooms >15 then delete;
if bathrooms = 8 then delete;
if sqft_living > 6000 then delete;
if sqft_lot > 40000 then delete;
if sqft_above > 5000 then delete;
if sqft_basement > 4000 then delete;
if sqft_living15 > 5000 then delete;
if sqft_lot15 > 60000 then delete;
run;


********************** SPLIT DATA TO TRAIN AND TEST*********************;
* train and test;
PROC SURVEYSELECT DATA = house OUT = xv_all SEED = 150830 SAMPRATE = 0.75 OUTALL;
run;

* check if the split was done corectly;
proc freq data = xv_all;
tables selected;
run;

data xv_all;
set xv_all;
if selected then new_y = ln_price; 
run;
proc print data = xv_all (obs = 10); 
run;


*********************************************************************;

* full model (sqft_above, sqft_living already removed);
proc reg data = xv_all;
model new_y = bedrooms bathrooms sqft_living sqft_lot floors waterfront view
condition grade basement yr_built renovated_num 
zipcode_num sqft_living15 sqft_lot15/ stb vif;
run;

* selection = stepwise;
proc reg;
model new_y = bedrooms bathrooms sqft_living sqft_lot floors waterfront view
condition grade basement yr_built renovated_num 
zipcode_num sqft_living15 sqft_lot15/ selection = stepwise stb vif;
run;

* selection = adjrsq;
proc reg;
model new_y = bedrooms bathrooms sqft_living sqft_lot floors waterfront view
condition grade sqft_above sqft_basement yr_built renovated_num 
zipcode_num sqft_living15 sqft_lot15/ selection = adjrsq stb vif;
run;

*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!final model!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!;
* all significant variables;
proc reg data = xv_all;
model new_y = bedrooms bathrooms sqft_living floors waterfront view
condition grade basement yr_built zipcode_num sqft_living15/ stb;
run;
*adjr2= 0.6416;

* feature selection (-bedrooms);
proc reg data = xv_all;
model new_y =  bathrooms sqft_living floors waterfront view
condition grade basement yr_built zipcode_num sqft_living15/ stb;
run;
*adjr2= 0.6394;

* feature selection ( -view);
proc reg data = xv_all;
model new_y =   bathrooms sqft_living floors waterfront
condition grade basement yr_built zipcode_num sqft_living15/ stb;
run;
*adjr2= 0.6380;

* feature selection ( -condition);
proc reg data = xv_all;
model new_y =   bathrooms sqft_living floors waterfront
grade basement yr_built zipcode_num sqft_living15/ stb;
run;
*adjr2= 0.6356;

* feature selection ( -basement);
proc reg data = xv_all;
model new_y =   bathrooms sqft_living floors waterfront
grade yr_built zipcode_num sqft_living15/ stb;
run;
*adjr2= 0.6327;

********************************************************************;
* feature selection ( -floor);
proc reg data = xv_all;
model new_y =  bathrooms sqft_living waterfront
grade yr_built zipcode_num sqft_living15/ stb;
run;
* adjr2= 0.6310;
* all features with p-value <0.0001 and relatively high standardized estimates;
********************************************************************;

* Residual;
proc reg;
title;
model new_y =  bathrooms sqft_living waterfront
grade yr_built zipcode_num sqft_living15/stb;
plot student.*predicted.;
plot student.*( bathrooms sqft_living waterfront
grade yr_built zipcode_num sqft_living15);
plot npp.*student.;
run;

title "Validation - Test Set";
proc reg data=xv_all;
* Final Model; 
model new_y = bathrooms sqft_living waterfront
grade yr_built zipcode_num sqft_living15;
output out=outm1(where=(new_y=.)) p=yhat;
run;

proc print data=outm1 (obs=10);
run;

title "Final Model - Difference between Observed and Predicted in Test Set";
data outm1_sum;
set outm1;
d = ln_price - yhat;
absd = abs(d);
run;
proc summary data = outm1_sum;
var d absd;
output out = outm1_stats std(d) = rmse mean(absd) = mae ;
run;
proc print data=outm1_stats;
title 'Final Model -Validation statistics';
run;
*computes correlation of observed and predicted values in test set; 
proc corr data = outm1;
var ln_price yhat;
run;

