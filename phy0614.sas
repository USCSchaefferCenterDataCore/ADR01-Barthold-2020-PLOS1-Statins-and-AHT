/*********************************************************************************************/
title1 'Physicians Visits 06-13';

* Author: PF;
* Summary:
	•	Input: bsfcuYYYY.dta, 06-13
	•	Output: phy_0613.dta, phy_long0613.do
	•	Brings in the BSF cost and use files, gets count for number of physician visits during the year. 
		Makes a wide file and a long file. ;
	
options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mergenoby=warn 
	varlenchk=error dkrocond=error msglevel=i merror mprint;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
%partABlib(types=bsf);
libname repbase "../../../data/aht/base";

* Bring in data sets;
%macro base;
%do year=2006 %to 2012;
data bsf&year.; set bsf.bsfcu&year. (keep=bene_id em_events phys_events); run;
%end;
%mend;

%base;

* 2013 has different var names;
data bsf2013;
	set bsf.bsfcu2013 (keep=bene_id em_event phys_eve);
	rename phys_eve=phys_events em_event=em_events;
run;

data bsf2014;
	set bsf.bsfcu2014 (keep=bene_id em_event phys_eve);
	rename phys_eve=phys_events em_event=em_events;
run;

/********* Wide File **********/
%macro wide;
%do year=2006 %to 2014;
data wide&year.;
	set bsf&year.;
	if phys_events ne . then phyvis_&year=phys_events;
	else phyvis_&year.=0;
	drop em_events phys_events;
run;

proc means data=wide&year.;
	title3 "Total Phys Visits &Year.";
	output out=phyvis_&year. sum(phyvis_&year.)=;
run;

proc sort data=wide&year.; by bene_id; run;
%end;
%mend;

%wide;

data wide_all;
	merge wide2006-wide2014;
	by bene_id;
run;

* create perm;
data repbase.phy_0614;
	set wide_all;
run;


/********* Long File **********/
%macro long;
%do year=2006 %to 2014;
data long&year.;
	set bsf&year.;
	year=&year.;
	if phys_events ne . then phyvis=phys_events;
	else phyvis=0;
	drop em_events phys_events;
run;
%end;
%mend;

%long;

data long_all;
	set long2006-long2014;
run;

* Create perm;
data repbase.phy_long0614;
	set long_all;
run; 

* Checks;
proc univariate data=wide_all; var phyvis_2006-phyvis_2014; run;
proc univariate data=long_all; var phyvis; run;





