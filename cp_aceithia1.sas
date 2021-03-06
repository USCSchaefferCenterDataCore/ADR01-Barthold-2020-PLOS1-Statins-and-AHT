/*********************************************************************************************/
title1 'Drug Use for aceithia';

* Summary:
	?	Input: pdeYYYY.dta, fdb_ndc_extract.dta, ipcYYYY.dta, snfcYYYY.dta
	?	Output: XXXX(so)_XXXX_YYYYp.dta, 0713
	?	For drugs of interest, pulls users from 06-13, by class name 
	o	Classes determined by ndcbyclass.do 
	?	Makes arrays of use to characterize use during the year. Pushes forward extra pills from early fills, the last fill of the year, IP days, and SNF days. 
	o	New patricia push, and gets rid of repeat claims on the same day.
	?	Makes wide file, showing days of use in each unit of time.
	?	These classes exist, but there are no claims: a2rbcchb a2rbbblo a2rbcchbthia cchbthia;
	
options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
 mergenoby=warn varlenchk=error varinitchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/	

%include "../../../../../../51866/PROGRAMS/setup.inc";
libname fdb "&datalib.Extracts/FDB/";
%partABlib(types=snf ip);
%partDlib(types=pde);
libname reppoly "../../../../data/aht/poly/";

/*********** NDC Level file with aceithia ************/
data aceithia;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	if hic3_desc in("ACE INHIBITOR-THIAZIDE OR THIAZIDE-LIKE DIURETIC") then aceithia=1;

	if aceithia=1;
	
run;

proc sort data=aceithia; by ndc; run;
	
/************* aceithia Pull **************/

%macro aceithiapull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) aceithia (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) pde&prev_year._10 (in=b keep=bene_id aceithia_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in aceithiaa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,aceithia_push_&prev_year.);

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

	array aceithia_a [*] aceithia_a1-aceithia_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and aceithia=1 then aceithia_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=aceithia_clms_&year.)
	sum(dayssply)=aceithia_filldays_&year. min(srvc_dt)=aceithia_minfilldt_&year. max(srvc_dt)=aceithia_maxfilldt_&year.
	max(aceithia_a1-aceithia_a365 earlyfill_push lastfill_push aceithia)=;
run;

data pde&year._6;
	set pde&year._5;
	aceithia_fillperiod_&year.=max(aceithia_maxfilldt_&year.-aceithia_minfilldt_&year.+1,0);
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

	array aceithia_a [*] aceithia_a1-aceithia_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if aceithia_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the aceithia_a is 1, do nothing (already added it to the snf_push);
		* if the aceithia_a spot is empty, then filling in with snf_push;
		if snf_push>0 and aceithia_a[i]=. then do;
			aceithia_a[i]=1;
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

	array aceithia_a [*] aceithia_a1-aceithia_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if aceithia_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the aceithia_a is 1, do nothing (already added to the ips_push);
		* if the aceithia_a spot is not full then adding in the ips_push;
		if ips_push>0 and aceithia_a[i]=. then do;
			aceithia_a[i]=1;
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

	aceithia_pdays_&year=max(min(sum(of aceithia_a1-aceithia_a365),365),0);

	drop aceithia_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data pde&year._10;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  aceithia_push_&year.=max(lastfill_push,inyear_push);
  if aceithia_push_&year.<0 then aceithia_push_&year.=0;
  if aceithia_push_&year.>90 then aceithia_push_&year.=90;
  keep bene_id aceithia:;
run;

* create perm;
data reppoly.aceithia_&year.p;
	set pde&year._10;
run;

%mend aceithiapull;

%aceithiapull(2006,2005,*,);
%aceithiapull(2007,2006,,*);
%aceithiapull(2008,2007,,*);
%aceithiapull(2009,2008,,*);
%aceithiapull(2010,2009,,*);
%aceithiapull(2011,2010,,*);
%aceithiapull(2012,2011,,*);
%aceithiapull(2013,2012,,*);

/*********** Merge aceithia 07-13 **********/
data aceithia_0713;
	merge pde2007_10 (in=b)
				pde2008_10 (in=c)
				pde2009_10 (in=d)
				pde2010_10 (in=e)
				pde2011_10 (in=f)
				pde2012_10 (in=g)
				pde2013_10 (in=h);
	by bene_id;
	yaceithia2007=b;
	yaceithia2008=c;
	yaceithia2009=d;
	yaceithia2010=e;
	yaceithia2011=f;
	yaceithia2012=g;
	yaceithia2013=h;

	* timing variables;
	array yaceithia [*] yaceithia2007-yaceithia2013;
	array yaceithiadec [*] yaceithia2013 yaceithia2012 yaceithia2011 yaceithia2010 yaceithia2009 yaceithia2008 yaceithia2007 ;
	do i=1 to dim(yaceithia);
		if yaceithia[i]=1 then aceithia_lastyoo=i+2006;
		if yaceithiadec[i]=1 then aceithia_firstyoo=2014-i;
	end;

	aceithia_yearcount=aceithia_lastyoo-aceithia_firstyoo+1;

	* utilization variables;
	array util [*] aceithia_fillperiod_2007-aceithia_fillperiod_2013 aceithia_clms_2007 - aceithia_clms_2013
		aceithia_filldays_2007-aceithia_filldays_2013 aceithia_pdays_2007-aceithia_pdays_2013;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	aceithia_clms=sum(of aceithia_clms_2007-aceithia_clms_2013);
	aceithia_filldays=sum(of aceithia_filldays_2007-aceithia_filldays_2013);
	aceithia_pdays=sum(of aceithia_pdays_2007-aceithia_pdays_2013);

	* timing variables;
	aceithia_minfilldt=min(of aceithia_minfilldt_2007-aceithia_minfilldt_2013);
	aceithia_maxfilldt=max(of aceithia_maxfilldt_2007-aceithia_maxfilldt_2013);

	aceithia_fillperiod=aceithia_maxfilldt - aceithia_minfilldt+1;

	aceithia_pdayspy=aceithia_pdays/aceithia_yearcount;
	aceithia_filldayspy=aceithia_filldays/aceithia_yearcount;
	aceithia_clmspy=aceithia_clms/aceithia_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* create perm;
data reppoly.aceithia_0713p;
	set aceithia_0713;
run;

* checks;
proc means data=aceithia_0713; run;











