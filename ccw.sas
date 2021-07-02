/***************************************************************************************************/
title1 "CCW";

* Author: PF;
* Summary of original program:
	•	Input: bsfccYYYY.dta, 06-13.
	•	Output: ccw_0613.dta, ccw_0713.dta, ccw_9913.dta, ccw_long0213
	•	Merges ccw files, makes variables for the diagnosis date of the key comorbidities;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict 
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i mprint;

/**************************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";

%partABlib(types=bsf);

libname repbase "../../../data/aht/base";

* Bringing in ccw data;
%macro data;
%do year=2007 %to 2014;
data ccw&year;
	set bsf.bsfcc&year. 
	(keep=bene_id amie atrialfe diabtese strktiae hypert_ever hyperl_ever alzhe alzhdmte
	 rename=(amie=amie_&year atrialfe=atrialfe_&year diabtese=diabtese_&year strktiae=strktiae_&year hypert_ever=hypert_ever_&year
	 hyperl_ever=hyperl_ever_&year alzhe=alzhe_&year alzhdmte=alzhdmte_&year));
	by bene_id;
	year=&year.;
	if first.bene_id;
run;
%end;

data repbase.ccw_0714;
	merge %do year=2007 %to 2014;
		ccw&year
	%end;;
	by bene_id;
	amie=min(of amie_2007-amie_2014);
	atrialfe=min(of atrialfe_2007-atrialfe_2014);
	diabtese=min(of diabtese_2007-diabtese_2014);
	strktiae=min(of strktiae_2007-strktiae_2014);
	hypert_ever=min(of hypert_ever_2007-hypert_ever_2014);
	hyperl_ever=min(of hyperl_ever_2007-hyperl_ever_2014);
	alzhe=min(of alzhe_2007-alzhe_2014);
	alzhdmte=min(of alzhdmte_2007-alzhdmte_2014);
	year_alzhe=year(alzhe);
	format amie: atrialfe: diabtese: strktiae: hypert_ever: hyperl_ever: alzhe: alzhdmte: mmddyy10.;
run;
%mend;

%data;

/* checks */
proc freq data=repbase.ccw_0714;
	table year_alzhe;
run;
	
options obs=100;
proc print data=repbase.ccw_0714; run;
	
