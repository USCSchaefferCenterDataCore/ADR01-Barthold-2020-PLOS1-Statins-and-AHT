/*********************************************************************************************/
title1 'AHT Drug Use - Long';
	
* Author: PF;
* Summary:
	•	Input: XXXX(so)_XXXX_YYYY.dta, 0713
	o	insamp_0713.dta
	•	Output: ahtco_YYYY.dta, ahtco_long0713a.dta
	•	Merges the 14 classes (solos and combos) for each year. Make year variable. Fill in zeros. Restrict to the people who were insamp in that year. (Note they could still die that year).
	•	Append the 7 years to get long file.;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../../51866/PROGRAMS/setup.inc";
libname repbase "../../../../data/aht/base/";
libname reppoly "../../../../data/aht/poly/";

/********* Merge the 10 AHTs within each year **********/

data insamp;
	set repbase.insamp_0714;
run;

%macro years;

%do year=2007 %to 2014;

%let ahts=a2rbso aceiso aceicchb aceithia a2rbthia bbloso bblothia cchbso loopso thiaso;
%let v=1;
%let drug=%scan(&ahts,&v," ");

%do %while (%length(&drug)>0);
data &drug._&year.; 
	set reppoly.&drug._&year.p (keep=bene_id &drug._pdays_&year &drug._clms_&year);
	rename &drug._pdays_&year.=&drug._pdays &drug._clms_&year.=&drug._clms;
run;

%let v=%eval(&v+1);
%let drug=%scan(&ahts,&v," ");

%end;


%macro listvars(vlist=,vpre=,vsuf=);
%let v=1;
%let var=%scan(&vlist,&v);
%do %while (%length(&var)>0);

	&vpre&var&vsuf

	%let v=%eval(&v+1);
	%let var=%scan(&vlist,&v);

%end;
%mend;

data ahtco_&year.;
	merge %listvars(vlist=&ahts,vsuf=_&year);
	by bene_id;
	year=&year.;
	array var [*] %listvars(vlist=&ahts,vsuf=_pdays) %listvars(vlist=&ahts,vsuf=_clms);;
			
	do i=1 to dim(var);
		if var[i]=. then var[i]=0;
	end;
	
	ahtco_clms=sum(aceiso_clms,aceicchb_clms,aceithia_clms,a2rbso_clms,a2rbthia_clms,bbloso_clms,bblothia_clms,cchbso_clms,loopso_clms,thiaso_clms);
	ahtco_pdays=sum(aceiso_pdays,aceicchb_pdays,aceithia_pdays,a2rbso_pdays,a2rbthia_pdays,bbloso_pdays,bblothia_pdays,cchbso_pdays,loopso_pdays,thiaso_pdays);
	
	drop i;
run;

data ahtco_a&year.;
	merge ahtco_&year. (in=a) insamp (in=b rename=(age_beg_&year=age));
	by bene_id;
	if a and b;
	if insamp_&year=1;
	drop age_beg:;
run;

* create perm;
data reppoly.ahtco_&year.;
	set ahtco_a&year.;
run;

%end;

%mend;

%years;


/******** Append the ahtco files from 07-13 to get long file ********/
data ahtco_0714;
	set ahtco_a2007-ahtco_a2014;
run;

* create perm;
data reppoly.ahtco_long0714a;
	set ahtco_0714;
run;


proc means data=ahtco_0714; run;

