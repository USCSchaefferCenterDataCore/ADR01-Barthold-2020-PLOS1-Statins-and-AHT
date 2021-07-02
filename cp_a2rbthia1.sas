/*********************************************************************************************/
title1 'Drug Use for a2rbthia';

* Summary:
	•	Input: pdeYYYY.dta, fdb_ndc_extract.dta, ipcYYYY.dta, snfcYYYY.dta
	•	Output: XXXX(so)_XXXX_YYYYp.dta, 0713
	•	For drugs of interest, pulls users from 06-13, by class name 
	o	Classes determined by ndcbyclass.do 
	•	Makes arrays of use to characterize use during the year. Pushes forward extra pills from early fills, the last fill of the year, IP days, and SNF days. 
	o	New patricia push, and gets rid of repeat claims on the same day.
	•	Makes wide file, showing days of use in each unit of time.
	•	These classes exist, but there are no claims: a2rbcchb a2rbbblo a2rbcchbthia cchbthia;
	
options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
 mergenoby=warn varlenchk=error varinitchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/	

%include "../../../../../../51866/PROGRAMS/setup.inc";
libname fdb "&datalib.Extracts/FDB/";
%partABlib(types=snf ip);
%partDlib(types=pde);
libname reppoly "../../../../data/aht/poly/";

/*********** NDC Level file with a2rbthia ************/
data a2rbthia;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	if hic3_desc in("ANGIOTENSIN RECEPTOR ANTAG.-THIAZIDE DIURETIC COMB") then a2rbthia=1;

	if a2rbthia=1;
	
run;

proc sort data=a2rbthia; by ndc; run;
	
/************* a2rbthia Pull **************/

%macro a2rbthiapull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) a2rbthia (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) pde&prev_year._10 (in=b keep=bene_id a2rbthia_push_&prev_year.);
	by bene_id;
	&merge. if a; *is this supposed to be an if a merge?;
run;

* If there are multiple claims on the same day for the same beneficiary, we think those
prescriptions are meant to be taken together, meaning that if it is two 30 day fills, it is worth
30 possession days, not 60. So, we will take the max of the two claims on the same day, and then drop
one of the observations. ;

proc sort data=pde&year._2; by bene_id srvc_dt dayssply; run;

data pde&year._2a;
	set pde&year._2;
	by bene_id srvc_dt dayssply;
	if last.srvc_dt;
run;

* Early fills pushes
	- for people that fill their prescription before emptying their last, carry the extra pills forward
	- extrapill_push is the amount, from that fill date, that is superfluous for reaching the next fill date. Capped at 10;

data pde&year._3;
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in a2rbthiaa;
	if _n_ ne obs then set pde&year._2a (firstobs=2 keep=srvc_dt rename=(srvc_dt=uplag_srvc_dt));
	set pde&year._2a nobs=obs;
	count+1;
run;

proc sort data=pde&year._3; by bene_id srvc_dt count; run;

data pde&year._4;
	set pde&year._3;
	by bene_id srvc_dt;
	if last.bene_id then uplag_srvc_dt=.;
	
	* fixed doy;
	doy_srvc_dt=intck('day',mdy(1,1,&year),srvc_dt)+1;
	doy_uplag_srvc_dt=intck('day',mdy(1,1,&year),uplag_srvc_dt)+1;
	
	extrapill_push=(doy_srvc_dt+dayssply)-doy_uplag_srvc_dt; * will be blank at the end of the year;
	if extrapill_push<0 then extrapill_push=0;
	if extrapill_push>10 then extrapill_push=10;
	* pushstock is the accumulated stock of extra pills. Capped at 10;
	pushstock=extrapill_push;
	&merge. if first.bene_id then pushstock=sum(pushstock,a2rbthia_push_&prev_year.);

	* The methodology below will do the following:
  	1. Add the previous pushstock to the current pushstock
  	2. Calculate the number of pills to be added to the dayssply, which is the minimum of the
  		 need or the pushstock. Dayssply2=sum(dayssply,min(need,pushstock1))
  	3. Subtract the need from the pushstock sum and capping the minimum at 0 so that pushstock will never be negative.
  		 E.g. if the need is 5 and the pushstock is 3, the pushstock will be the max of 0 and -2 which is 0.
    4. Make sure the max of the pushstock that gets carried into the next day is 10.
       E.g. if the pushstock before substracting the need is 15, need is 3 then the pushstock is 15-3=12
       the pushstock that gets carried over will be the min of 10 or 12, which is 10.;

 	* creating need variable;
 	need = doy_uplag_srvc_dt-(sum(doy_srvc_dt,dayssply));
 	if last.bene_id then need=365-(sum(doy_srvc_dt,dayssply));
 	if need < 0 then need = 0 ;

 	* pushing extra pills forward;
 	retain pushstock1; * first retaining pushstock1 so that the previous pushstock will get moved to the next one;
 	if first.bene_id then pushstock1=0; * resetting the pushstock1 to 0 at the beginning of the year;
 	pushstock1=sum(pushstock1,pushstock);
 	dayssply2=sum(dayssply,min(need,pushstock1));
 	pushstock1=min(max(sum(pushstock1,-need),0),10);

	if last.bene_id then do;
		* final push from early fills;
		earlyfill_push=min(max(pushstock1,0),10);
		* extra pills from last prescription at end of year is capped at 90;
		lastfill_push=min(max(doy_srvc_dt+dayssply-365,0),90);
	end;

	array a2rbthia_a [*] a2rbthia_a1-a2rbthia_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and a2rbthia=1 then a2rbthia_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=a2rbthia_clms_&year.)
	sum(dayssply)=a2rbthia_filldays_&year. min(srvc_dt)=a2rbthia_minfilldt_&year. max(srvc_dt)=a2rbthia_maxfilldt_&year.
	max(a2rbthia_a1-a2rbthia_a365 earlyfill_push lastfill_push a2rbthia)=;
run;

data pde&year._6;
	set pde&year._5;
	a2rbthia_fillperiod_&year.=max(a2rbthia_maxfilldt_&year.-a2rbthia_minfilldt_&year.+1,0);
run;

/********** Bring in SNF **********/
data snf&year.;
	set snf.snfc&year. (keep=bene_id from_dt thru_dt);
run;

* First merging to keep people of interest;
data pde&year._snf;
	merge pde&year._6 (in=a keep=bene_id) snf&year. (in=b);
	by bene_id;
	if a;

	* changing to match with dougs;
	doy_from_dt=intck('day',mdy(1,1,&year),from_dt)+1;
	doy_thru_dt=intck('day',mdy(1,1,&year),thru_dt)+1;

	array snf_a [*] snf_a1-snf_a365;

	do i=1 to 365;
		if doy_from_dt <= i <= doy_thru_dt then snf_a[i]=1;
	end;

	drop from_dt thru_dt doy_from_dt doy_thru_dt;
run;

proc means data=pde&year._snf nway noprint;
	class bene_id;
	output out=pde&year._snf1 (drop=_type_ _freq_) max(snf_a1-snf_a365)=;
run;

* Merging to entire class array data set;
data pde&year._7;
	merge pde&year._6 (in=a) pde&year._snf1 (in=b);
	by bene_id;
	if a;

	** SNF push;
	* snf_push is the extra days added for SNF days concurrent with drug days;

	array a2rbthia_a [*] a2rbthia_a1-a2rbthia_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if a2rbthia_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the a2rbthia_a is 1, do nothing (already added it to the snf_push);
		* if the a2rbthia_a spot is empty, then filling in with snf_push;
		if snf_push>0 and a2rbthia_a[i]=. then do;
			a2rbthia_a[i]=1;
			snf_push=snf_push-1;
			if snf_push>10 then snf_push=10;
		end;

	end;

	drop snf_a: i;
run;

/********* Bring in IP **********/
data ip&year.;
	set ip.ipc&year. (keep=bene_id from_dt thru_dt);
run;

data pde&year._ip;
	merge pde&year._7 (in=a keep=bene_id) ip&year. (in=b);
	by bene_id;
	if a;

	* changing to match with dougs;
	doy_from_dt=intck('day',mdy(1,1,&year),from_dt)+1;
	doy_thru_dt=intck('day',mdy(1,1,&year),thru_dt)+1;

	array ips_a [*] ips_a1-ips_a365;

	do i=1 to 365;
		if doy_from_dt <= i <= doy_thru_dt then ips_a[i]=1;
	end;

	drop from_dt thru_dt doy_from_dt doy_thru_dt;
run;

proc means data=pde&year._ip nway noprint;
	class bene_id;
	output out=pde&year._ip1 (drop=_type_ _freq_)
	max(ips_a1-ips_a365)=;
run;

data pde&year._8;
	merge pde&year._7 (in=a) pde&year._ip1 (in=b);
	by bene_id;
	if a;

	** IP Push;
	* ips_push is the extra days added for ip days concurrent with drug days;

	array a2rbthia_a [*] a2rbthia_a1-a2rbthia_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if a2rbthia_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the a2rbthia_a is 1, do nothing (already added to the ips_push);
		* if the a2rbthia_a spot is not full then adding in the ips_push;
		if ips_push>0 and a2rbthia_a[i]=. then do;
			a2rbthia_a[i]=1;
			ips_push=ips_push-1;
			if ips_push>10 then ips_push=10;
		end;

	end;

	drop ips_a:;

run;

** Final consumption day calculations;

data pde&year._9;
	set pde&year._8;

	* The array is filled using dayssply2, which includes adjustments for early fills.
	Then, the array is adjusted further for IPS and SNF days. So, the sum of the ones in the array is
	the total &year. consumption days.;
	
	a2rbthia_pdays_&year=max(min(sum(of a2rbthia_a1-a2rbthia_a365),365),0);

	drop a2rbthia_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data pde&year._10;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  a2rbthia_push_&year.=max(lastfill_push,inyear_push);
  if a2rbthia_push_&year.<0 then a2rbthia_push_&year.=0;
  if a2rbthia_push_&year.>90 then a2rbthia_push_&year.=90;
  keep bene_id a2rbthia:;
run;

* create perm;
data reppoly.a2rbthia_&year.p;
	set pde&year._10;
run;

%mend a2rbthiapull;

%a2rbthiapull(2006,2005,*,);
%a2rbthiapull(2007,2006,,*);
%a2rbthiapull(2008,2007,,*);
%a2rbthiapull(2009,2008,,*);
%a2rbthiapull(2010,2009,,*);
%a2rbthiapull(2011,2010,,*);
%a2rbthiapull(2012,2011,,*);
%a2rbthiapull(2013,2012,,*);

/*********** Merge a2rbthia 07-13 **********/
data a2rbthia_0713;
	merge pde2007_10 (in=b)
				pde2008_10 (in=c)
				pde2009_10 (in=d)
				pde2010_10 (in=e)
				pde2011_10 (in=f)
				pde2012_10 (in=g)
				pde2013_10 (in=h);
	by bene_id;
	ya2rbthia2007=b;
	ya2rbthia2008=c;
	ya2rbthia2009=d;
	ya2rbthia2010=e;
	ya2rbthia2011=f;
	ya2rbthia2012=g;
	ya2rbthia2013=h;

	* timing variables;
	array ya2rbthia [*] ya2rbthia2007-ya2rbthia2013;
	array ya2rbthiadec [*] ya2rbthia2013 ya2rbthia2012 ya2rbthia2011 ya2rbthia2010 ya2rbthia2009 ya2rbthia2008 ya2rbthia2007 ;
	do i=1 to dim(ya2rbthia);
		if ya2rbthia[i]=1 then a2rbthia_lastyoo=i+2006;
		if ya2rbthiadec[i]=1 then a2rbthia_firstyoo=2014-i;
	end;

	a2rbthia_yearcount=a2rbthia_lastyoo-a2rbthia_firstyoo+1;

	* utilization variables;
	array util [*] a2rbthia_fillperiod_2007-a2rbthia_fillperiod_2013 a2rbthia_clms_2007 - a2rbthia_clms_2013
		a2rbthia_filldays_2007-a2rbthia_filldays_2013 a2rbthia_pdays_2007-a2rbthia_pdays_2013;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	a2rbthia_clms=sum(of a2rbthia_clms_2007-a2rbthia_clms_2013);
	a2rbthia_filldays=sum(of a2rbthia_filldays_2007-a2rbthia_filldays_2013);
	a2rbthia_pdays=sum(of a2rbthia_pdays_2007-a2rbthia_pdays_2013);

	* timing variables;
	a2rbthia_minfilldt=min(of a2rbthia_minfilldt_2007-a2rbthia_minfilldt_2013);
	a2rbthia_maxfilldt=max(of a2rbthia_maxfilldt_2007-a2rbthia_maxfilldt_2013);

	a2rbthia_fillperiod=a2rbthia_maxfilldt - a2rbthia_minfilldt+1;

	a2rbthia_pdayspy=a2rbthia_pdays/a2rbthia_yearcount;
	a2rbthia_filldayspy=a2rbthia_filldays/a2rbthia_yearcount;
	a2rbthia_clmspy=a2rbthia_clms/a2rbthia_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* create perm;
data reppoly.a2rbthia_0713p;
	set a2rbthia_0713;
run;

* checks;
proc means data=a2rbthia_0713; run;











