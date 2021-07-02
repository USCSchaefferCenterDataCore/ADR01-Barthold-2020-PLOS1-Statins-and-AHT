/*********************************************************************************************/
title1 'AD Drug Use - Long';
	
* Summary:
	•	Input: XXXXX_YYYY.dta for donep galan meman rivas
	•	Output: adrx_long0713.dta
	•	Merges the 4 classes for each year. Make year variable. Fill in zeros. 
	•	Append the 7 years to get long file.

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint 
	mergenoby=warn varlenchk=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
libname addrug "../../../data/aht/addrug/";

/******** Merge the 4 classes of drugs within each year  *********/

%macro years;

%do year=2007 %to 2014;

%macro addrug(drug);
data &drug._&year.; 
	set addrug.&drug._&year.p (keep=bene_id &drug._pdays_&year &drug._clms_&year);
	rename &drug._pdays_&year.=&drug._pdays &drug._clms_&year.=&drug._clms;
run;

proc sort data=&drug._&year.; by bene_id; run;
%mend;

%addrug(donep);
%addrug(galan);
%addrug(meman);
%addrug(rivas);

data adrx_&year.;
	merge donep_&year. galan_&year. meman_&year. rivas_&year.;
	by bene_id;
	year=&year.;
	array var [*] donep_pdays galan_pdays meman_pdays rivas_pdays donep_clms galan_clms meman_clms rivas_clms;
	do i=1 to dim(var);
		if var[i]=. then var[i]=0;
	end;
	
	adrx_clms=sum(donep_clms,galan_clms,meman_clms,rivas_clms);
	adrx_pdays=sum(donep_pdays,galan_pdays,meman_pdays,rivas_pdays);
	
	drop i;
	
run;

* create perm;
data addrug.adrx_&year.;
	set adrx_&year.;
run;

%end;

%mend;

%years;

/******** Append the adrx files from 07-13 to get long file ********/
data adrx_0714;
	set adrx_2007-adrx_2014;
run;

* create perm;
data addrug.adrx_long0714;
	set adrx_0714;
run;

* checks;
proc means data=adrx_0714; run;
