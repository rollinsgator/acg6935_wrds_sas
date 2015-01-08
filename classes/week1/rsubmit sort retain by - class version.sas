
/*
  remote access: setup
*/

%let wrds = wrds.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;


/* execute code remotely within rsubmit-endrsubmit code block 
   note that after 15 or so minutes of inactivity, you need to sign on again
*/
rsubmit;
/* hi */
endrsubmit;

/* get some records from Compustat Funda */

rsubmit;

data myTable (keep = gvkey fyear datadate sale at ni prcc_f csho);
set comp.funda;
/* require fyear to be within 2010-2013 */
if 2010 <=fyear <= 2013;
/* prevent double records */
if indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C' ;
run;
proc download data=myTable out=myCompTable;run;
endrsubmit;



/* does myCompTable have duplicate gvkey-fyear rows? */

proc sort data=myCompTable nodupkey dupout=mydouble; by gvkey fyear;run;


rsubmit;

data myTable ;
set comp.funda;
/* require fyear to be within 2010-2013 */
if 2010 <=fyear <= 2013;
where gvkey eq "186121";
/* prevent double records */
if indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C' ;
run;
proc download data=myTable out=mydouble2;run;
endrsubmit;

/* create an indicator =1 if sales increase */

/* 'dirty' 
	will not work for first year of data for each firm
*/
data myDirtyTable (keep = gvkey fyear sale sale_prev increase);
set myCompTable;
retain sale_prev;
if _N_ <= 30;
increase = (sale > sale_prev);
sale_prev = sale;
run;

/* clean -- use 'by' statement, and set to missing for first firmyear */
data myCleanTable (keep = gvkey fyear sale sale_prev increase);
set myCompTable;
by gvkey;
retain sale_prev;
if _N_ <= 30;
increase = (sale > sale_prev); /*<-------------- condition */
if first.gvkey then increase = .;
sale_prev = sale; /* <---------- update previous sales */
run;

/* missing is represented by a large negative number */
data test;
miss = .;
somesmallval = 900;
larger = ( 1000 > miss); /* expect to be true */
larger2 = IFN ( 1000 > miss , 1, 0, .); /* does not work: (-1000 > miss) still is 1 */
larger3 = IFN ( miss ne . , ( 1000 > miss ), . ); /* expect to be .*/
larger4 = IFN ( somesmallval ne . , ( 1000 > somesmallval ), . ); /* expect to be 1 */
run;



/* subsample */
data myCompTable2 (keep = gvkey fyear sale);
set myCompTable;
retain sale;
if _N_ <= 30;
run;

/* using 'retain' by itself */
data myCompTable3;
set myCompTable2;
retain myNewVar -5; /* initial value of myNewVar is -5 */
sale_ln = log(sale);
myNewVar = myNewVar  + 1;
run;

/* compare without 'retain' */
data myCompTable3;
set myCompTable2;
/*retain myNewVar -5; */
if _N_ eq 1 then myNewVar = -5; /* using _N_ to set initial value of myNewVar */
myNewVar = myNewVar  + 1;
run;

/* let's count the number of fiscal years, and the number of loss years for each firm 
	using the data step with BY statement
	this requires a sort on 'gvkey' (it is already sorted though)
*/

/* just in case we have duplicate observations (same gvkey-fyear) we include 'nodupkey' */
proc sort data=myCompTable2 nodupkey; by gvkey fyear;run;

data countYears;
set myCompTable2;
by gvkey;
retain years lossyears ;
/* init for each gvkey (initial value in retain will only be used once) */
if first.gvkey then do;
  years = 0;
  lossyears = 0;
end;
/* increment years */
years = years + 1;
/* expression (<EXPR>) evaluates to 1 if true, 0 otherwise
 	so, (ni < 0) will be 1 if loss */
lossyears = lossyears + (ni < 0);
run;

/* what if we are only interested in the totals? 
	use 'output'
*/
data countYears (keep = gvkey years lossyears);
set myCompTable2;
by gvkey;
retain years  lossyears ;
/* init for each gvkey (initial value in retain will only be used once) */
if first.gvkey then do;
  years = 0;
  lossyears = 0;
end;
/* increment years */
years = years + 1;
/* expression (<EXPR>) evaluates to 1 if true, 0 otherwise
 	so, (ni < 0) will be 1 if loss */
lossyears = lossyears + (ni < 0);
/* only output last observation of each gvkey */
if last.gvkey then output;
run;

/* lets compute return on assets (ROA) and get some statistics: 
   #obs per firm, mean, max and standard deviation ROA
*/

/* subsample */
data roaInputs;
set myCompTable;
if at > 0  and ni ne . then roa = ni / at;
*roa = ni / at;
run;

/* sort required */
proc sort data=roaInputs nodupkey; by gvkey fyear ;run;

proc means data=roaInputs NOPRINT; /* suppress output to screen */
  /* but, do output to dataset */
  OUTPUT OUT=roaOutput n= mean= max= median= stddev= /autoname;
  var roa;
  by gvkey; /* without gvkey would give full sample statistics */
run;



/* there are some missing values for roa (missing net income or missing assets) 
	we could drop these observations, but what if we want to keep our sample 'whole'?
	-> add a 'where' clause to the data set being input
*/

proc means data=roaInputs (where= (roa ne .) ) NOPRINT; /* suppress output to screen */
  /* but, do output to dataset */
  OUTPUT OUT=roaOutput n= mean= max= median= stddev= /autoname;
  var roa;
  by gvkey; /* without gvkey would give full sample statistics */
run;

* note that roaInputs has 35151 rows, and that there were 34778 observations read 
from the data set WORK.ROAINPUTS. */

