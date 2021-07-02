/*********************************************************************************************/
title1 'Drug Use for thiaso';

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

/*********** NDC Level file with thiaso ************/
data thiaso;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	if hic3_desc in("THIAZIDE AND RELATED DIURETICS","RENIN INHIBITOR,DIRECT AND THIAZIDE DIURETIC COMB",
		"ALPHA-ADRENERGIC BLOCKING AGENT/THIAZIDE COMB") then thiaso=1;

	if thiaso=1;
	
run;

proc sort data=thiaso; by ndc; run;
	
/************* thiaso Pull **************/

%macro thiasopull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) thiaso (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) reppoly.thiaso_&prev_year.p (in=b keep=bene_id thiaso_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in thiasoa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,thiaso_push_&prev_year.);

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

	array thiaso_a [*] thiaso_a1-thiaso_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and thiaso=1 then thiaso_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=thiaso_clms_&year.)
	sum(dayssply)=thiaso_filldays_&year. min(srvc_dt)=thiaso_minfilldt_&year. max(srvc_dt)=thiaso_maxfilldt_&year.
	max(thiaso_a1-thiaso_a365 earlyfill_push lastfill_push thiaso)=;
run;

data pde&year._6;
	set pde&year._5;
	thiaso_fillperiod_&year.=max(thiaso_maxfilldt_&year.-thiaso_minfilldt_&year.+1,0);
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

	array thiaso_a [*] thiaso_a1-thiaso_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if thiaso_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the thiaso_a is 1, do nothing (already added it to the snf_push);
		* if the thiaso_a spot is empty, then filling in with snf_push;
		if snf_push>0 and thiaso_a[i]=. then do;
			thiaso_a[i]=1;
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

	drop from_dt thru_dt;
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

	array thiaso_a [*] thiaso_a1-thiaso_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if thiaso_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the thiaso_a is 1, do nothing (already added to the ips_push);
		* if the thiaso_a spot is not full then adding in the ips_push;
		if ips_push>0 and thiaso_a[i]=. then do;
			thiaso_a[i]=1;
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
	
	thiaso_pdays_&year=max(min(sum(of thiaso_a1-thiaso_a365),365),0);

	drop thiaso_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data pde&year._10;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  thiaso_push_&year.=max(lastfill_push,inyear_push);
  if thiaso_push_&year.<0 then thiaso_push_&year.=0;
  if thiaso_push_&year.>90 then thiaso_push_&year.=90;
  keep bene_id thiaso:;
run;

* create perm;
data reppoly.thiaso_&year.p;
	set pde&year._10;
run;

%mend thiasopull;

/*
%thiasopull(2006,2005,*,);
%thiasopull(2007,2006,,*);
%thiasopull(2008,2007,,*);
%thiasopull(2009,2008,,*);
%thiasopull(2010,2009,,*);
%thiasopull(2011,2010,,*);
%thiasopull(2012,2011,,*);
%thiasopull(2013,2012,,*);
*/
%thiasopull(2014,2013,,*);

/*********** Merge thiaso 07-14 **********/
data thiaso_0714;
	merge reppoly.thiaso_2007p (in=b)
				reppoly.thiaso_2008p (in=c)
				reppoly.thiaso_2009p (in=d)
				reppoly.thiaso_2010p (in=e)
				reppoly.thiaso_2011p (in=f)
				reppoly.thiaso_2012p (in=g)
				reppoly.thiaso_2013p (in=h)
				reppoly.thiaso_2014p (in=i);
	by bene_id;
	ythiaso2007=b;
	ythiaso2008=c;
	ythiaso2009=d;
	ythiaso2010=e;
	ythiaso2011=f;
	ythiaso2012=g;
	ythiaso2013=h;
	ythiaso2014=i;

	* timing variables;
	array ythiaso [*] ythiaso2007-ythiaso2014;
	array ythiasodec [*] ythiaso2014 ythiaso2013 ythiaso2012 ythiaso2011 ythiaso2010 ythiaso2009 ythiaso2008 ythiaso2007 ;
	do i=1 to dim(ythiaso);
		if ythiaso[i]=1 then thiaso_lastyoo=i+2006;
		if ythiasodec[i]=1 then thiaso_firstyoo=2015-i;
	end;

	thiaso_yearcount=thiaso_lastyoo-thiaso_firstyoo+1;

	* utilization variables;
	array util [*] thiaso_fillperiod_2007-thiaso_fillperiod_2014 thiaso_clms_2007 - thiaso_clms_2014
		thiaso_filldays_2007-thiaso_filldays_2014 thiaso_pdays_2007-thiaso_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	thiaso_clms=sum(of thiaso_clms_2007-thiaso_clms_2014);
	thiaso_filldays=sum(of thiaso_filldays_2007-thiaso_filldays_2014);
	thiaso_pdays=sum(of thiaso_pdays_2007-thiaso_pdays_2014);

	* timing variables;
	thiaso_minfilldt=min(of thiaso_minfilldt_2007-thiaso_minfilldt_2014);
	thiaso_maxfilldt=max(of thiaso_maxfilldt_2007-thiaso_maxfilldt_2014);

	thiaso_fillperiod=thiaso_maxfilldt - thiaso_minfilldt+1;

	thiaso_pdayspy=thiaso_pdays/thiaso_yearcount;
	thiaso_filldayspy=thiaso_filldays/thiaso_yearcount;
	thiaso_clmspy=thiaso_clms/thiaso_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* create perm;
data reppoly.thiaso_0714p;
	set thiaso_0714;
run;

* checks;
proc means data=thiaso_0714; run;











