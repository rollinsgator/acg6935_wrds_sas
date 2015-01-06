
/*
  remote access: setup
*/

%let wrds = wrds.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;


/* execute code remotely within rsubmit-endrsubmit code block 
   note that after 15 or so minutes of inactivity, you need to sign on again
*/
rsubmit;
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

endrsubmit;

/* download the newly created dataset 
	(this could have been done in the same rsubmit-endrsubmit block)
*/
rsubmit;
proc download data=myTable out=myCompTable;run;
endrsubmit;

/* subsample */
data myCompTable2;
set myCompTable;
if _N_ <= 30;
run;

/* using 'retain' by itself */
data myCompTable3;
set myCompTable2;
retain myNewVar -5; /* initial value of myNewVar is -5 */
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

