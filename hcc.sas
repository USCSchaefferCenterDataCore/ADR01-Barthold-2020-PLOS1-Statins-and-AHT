/*********************************************************************************************/
title1 'HCC Scores';
	
* Author: PF;
* Summary: 
	•	Input: bene_hcc10scoresYYYY.dta, 06-13. 
	•	Output: hcc_0613.dta
	•	Merges hcc files, makes variables for the hcc comm rating in each year. ;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error dkrocond=error msglevel=i mprint;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
libname hcc "&datalib.&clean_data.HealthStatus/HCCscores/";
libname repbase "../../../data/aht/base";

/* Don't have hcc scores for 2006, so only including 2007 on*/
%macro hcc(year);
%do year=2007 %to 2014;
data hcc&year.; set hcc.bene_hccscores&year. (keep=bene_id resolved_hccyr); run;
%end;
%mend;

%hcc;

/****** HCC Wide 06-14 ******/
/*
data hcc_wide_0614;
	format bene_id;
	merge 
	hcc2006 (in=a keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2006))
	hcc2007 (in=b keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2007))
	hcc2008 (in=c keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2008))
	hcc2009 (in=d keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2009))
	hcc2010 (in=e keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2010))
	hcc2011 (in=f keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2011))
	hcc2012 (in=g keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2012))
	hcc2013 (in=h keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2013))
	hcc2014 (in=i keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2014));	
	by bene_id;
	y2006=a;
	y2007=b;
	y2008=c;
	y2009=d;
	y2010=e;
	y2011=f;
	y2012=g;
	y2013=h;     
	y2014=i;  
	
	* Variables;
	array y [*] y2014 y2013 y2012 y2011 y2010 y2009 y2008 y2007 y2006;
	array hcc_comm_ [*] hcc_comm_2014 hcc_comm_2013 hcc_comm_2012 hcc_comm_2011 hcc_comm_2010 hcc_comm_2009 hcc_comm_2008 hcc_comm_2007 hcc_comm_2006;
	do i=1 to dim(y);
		if y[i]=1 then hcc_comm_earliest=hcc_comm_[i];
	end;
	
	drop y20: i;
	
run;

* create perm;
data repbase.hcc_0614;
	set hcc_wide_0614;
run;
*/


/********* HCC Wide 07-14 **********/
data hcc_wide_0714;
	format bene_id;
	merge 
	hcc2007 (in=b keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2007))
	hcc2008 (in=c keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2008))
	hcc2009 (in=d keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2009))
	hcc2010 (in=e keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2010))
	hcc2011 (in=f keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2011))
	hcc2012 (in=g keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2012))
	hcc2013 (in=h keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2013))
	hcc2014 (in=i keep=bene_id resolved_hccyr rename=(resolved_hccyr=hcc_comm_2014));
	by bene_id;
	y2007=b;
	y2008=c;
	y2009=d;
	y2010=e;
	y2011=f;
	y2012=g;
	y2013=h;   
	y2014=i;    
	
	* Variables;
	array y [*] y2014 y2013 y2012 y2011 y2010 y2009 y2008 y2007;
	array hcc_comm_ [*] hcc_comm_2014 hcc_comm_2013 hcc_comm_2012 hcc_comm_2011 hcc_comm_2010 hcc_comm_2009 hcc_comm_2008 hcc_comm_2007;
	do i=1 to dim(y);
		if y[i]=1 then hcc_comm_earliest=hcc_comm_[i];
	end;
	
	drop y20: i;
	
run;

proc sort data=hcc_wide_0714; by bene_id; run;

* create perm;
data repbase.hcc_0714;
	set hcc_wide_0714;
run;


/********** HCC Long 07-14 **********/
data hcc_long_0714;
	format bene_id year;
	set
	hcc2007 (in=b keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2008 (in=c keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2009 (in=d keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2010 (in=e keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2011 (in=f keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2012 (in=g keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2013 (in=h keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm)
	hcc2014 (in=i keep=bene_id resolved_hccyr rename=resolved_hccyr=hcc_comm);	
	if b then year=2007;
	if c then year=2008;
	if d then year=2009;
	if e then year=2010;
	if f then year=2011;
	if g then year=2012;
	if h then year=2013;  
	if i then year=2014;     
run;

proc sort data=hcc_long_0714; by bene_id year; run;

* create perm;
data repbase.hcc_long0714;
	set hcc_long_0714;
run;

* comparing the repbase against the real base;
/*proc univariate data=hcc_wide_0614; var hcc_comm_earliest; run;*/
proc means data=hcc_long_0714; run;




