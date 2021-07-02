/*********************************************************************************************/
title1 'Drug Use for simso';

* Summary:
	•	Input: XXXX_YYYYp.dta, 2007-2013, for atorso atorccb praso rosuso simso
	o	insamp_0713.dta
	•	Output: statins_long0713a.dta
	•	Make year variable. Restrict to the people who were insamp in that year. 
	•	Append the 7 years to get long file.;
	
options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
 mergenoby=warn varlenchk=error varinitchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/	

%include "../../../../../../51866/PROGRAMS/setup.inc";
libname fdb "&datalib.Extracts/FDB/";
%partABlib(types=snf ip);
%partDlib(types=pde);
libname statsaht "../../../../data/aht/statins+aht/";
libname base "../../../../data/aht/base";

/* Merge the 5 statins within each year */

%macro merge;
	
%do year=2007 %to 2014;
	
data statins_&year.p;
	merge statsaht.atorcchb_&year.p (in=a rename=(atorcchb_pdays_&year.=atorcchb_pdays atorcchb_clms_&year.=atorcchb_clms) 
				keep=atorcchb_pdays_&year. atorcchb_clms_&year. bene_id)
				statsaht.atorso_&year.p (in=a rename=(atorso_pdays_&year.=atorso_pdays atorso_clms_&year.=atorso_clms)
				keep=atorso_pdays_&year. atorso_clms_&year. bene_id)
				statsaht.praso_&year.p (in=a rename=(praso_pdays_&year.=praso_pdays praso_clms_&year.=praso_clms)
				keep=praso_pdays_&year. praso_clms_&year. bene_id)
				statsaht.rosuso_&year.p (in=a rename=(rosuso_pdays_&year.=rosuso_pdays rosuso_clms_&year.=rosuso_clms)
				keep=rosuso_pdays_&year. rosuso_clms_&year. bene_id)
				statsaht.simso_&year.p (in=a rename=(simso_pdays_&year.=simso_pdays simso_clms_&year.=simso_clms)
				keep=simso_pdays_&year. simso_clms_&year. bene_id);			 
	by bene_id;
	year=&year;
	array var [*] atorcchb_pdays atorcchb_clms atorso_pdays atorso_clms praso_pdays praso_clms rosuso_pdays rosuso_clms simso_pdays simso_clms;
	do i=1 to dim(var);
		if var[i]=. then var[i]=0;
	end;
run;

* Merge with insamp;
data statsaht.statins_&year.;
	merge statins_&year.p (in=a) base.insamp_0714 (in=b rename=age_beg_&year=age);
	by bene_id;
	if a and b;
	if insamp_&year;
	drop age_beg:;
run;

%end;
%mend;

%merge;

/* Append to get long file */
data statsaht.statins_long0714a;
	set statsaht.statins_2007-statsaht.statins_2014;
run;

* checks;
proc means data=statsaht.statins_long0714a; run;