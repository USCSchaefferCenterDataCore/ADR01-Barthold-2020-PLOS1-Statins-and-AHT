/*********************************************************************************************/
title1 'Drug Use for atorcchb';

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
libname statsaht "../../../../data/aht/statins+aht/";

/*********** NDC Level file with atorcchb ************/
data atorcchb;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	ndcn=ndc*1;
	
	atorcchb=(ndcn in(00069215030,00069216030,00069217030,00069218030,00069219030,00069225030,00069226030,
	00069227030,00069296030,00069297030,00069298030,00378616177,00378616277,00378616377,
	00378616405,00378616477,00378616505,00378616577,00378616605,00378616677,00378616777,
	00378616805,00378616877,00378616905,00378616977,00378617005,00378617077,00378617177,
	54868120700,54868520900,63304049930,63304050030,63304050130,63304050230,63304050330,
	63304058730,63304058830,63304058930,63304059030,63304059130,63304060330));

	if atorcchb=1;
	
run;

proc sort data=atorcchb; by ndc; run;
	
/************* atorcchb Pull **************/

%macro atorcchbpull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) atorcchb (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) statsaht.atorcchb_&prev_year.p (in=b keep=bene_id atorcchb_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in atorcchba;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,atorcchb_push_&prev_year.);

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

	array atorcchb_a [*] atorcchb_a1-atorcchb_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and atorcchb=1 then atorcchb_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=atorcchb_clms_&year.)
	sum(dayssply)=atorcchb_filldays_&year. min(srvc_dt)=atorcchb_minfilldt_&year. max(srvc_dt)=atorcchb_maxfilldt_&year.
	max(atorcchb_a1-atorcchb_a365 earlyfill_push lastfill_push atorcchb)=;
run;

data pde&year._6;
	set pde&year._5;
	atorcchb_fillperiod_&year.=max(atorcchb_maxfilldt_&year.-atorcchb_minfilldt_&year.+1,0);
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

	array atorcchb_a [*] atorcchb_a1-atorcchb_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if atorcchb_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the atorcchb_a is 1, do nothing (already added it to the snf_push);
		* if the atorcchb_a spot is empty, then filling in with snf_push;
		if snf_push>0 and atorcchb_a[i]=. then do;
			atorcchb_a[i]=1;
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

	array atorcchb_a [*] atorcchb_a1-atorcchb_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if atorcchb_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the atorcchb_a is 1, do nothing (already added to the ips_push);
		* if the atorcchb_a spot is not full then adding in the ips_push;
		if ips_push>0 and atorcchb_a[i]=. then do;
			atorcchb_a[i]=1;
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
	
	atorcchb_pdays_&year=max(min(sum(of atorcchb_a1-atorcchb_a365),365),0);

	drop atorcchb_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data statsaht.atorcchb_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  atorcchb_push_&year.=max(lastfill_push,inyear_push);
  if atorcchb_push_&year.<0 then atorcchb_push_&year.=0;
  if atorcchb_push_&year.>90 then atorcchb_push_&year.=90;
  keep bene_id atorcchb:;
run;

%mend atorcchbpull;

%atorcchbpull(2006,2005,*,);
%atorcchbpull(2007,2006,,*);
%atorcchbpull(2008,2007,,*);
%atorcchbpull(2009,2008,,*);
%atorcchbpull(2010,2009,,*);
%atorcchbpull(2011,2010,,*);
%atorcchbpull(2012,2011,,*);
%atorcchbpull(2013,2012,,*);
%atorcchbpull(2014,2013,,*);

/*********** Merge atorcchb 07-13 **********/
data statsaht.atorcchb_0714p;
	merge statsaht.atorcchb_2007p (in=b)
				statsaht.atorcchb_2008p (in=c)
				statsaht.atorcchb_2009p (in=d)
				statsaht.atorcchb_2010p (in=e)
				statsaht.atorcchb_2011p (in=f)
				statsaht.atorcchb_2012p (in=g)
				statsaht.atorcchb_2013p (in=h)
				statsaht.atorcchb_2014p (in=i);
	by bene_id;
	yatorcchb2007=b;
	yatorcchb2008=c;
	yatorcchb2009=d;
	yatorcchb2010=e;
	yatorcchb2011=f;
	yatorcchb2012=g;
	yatorcchb2013=h;
	yatorcchb2014=i;
	
	* timing variables;
	array yatorcchb [*] yatorcchb2007-yatorcchb2014;
	array yatorcchbdec [*] yatorcchb2014 yatorcchb2013 yatorcchb2012 yatorcchb2011 yatorcchb2010 yatorcchb2009 yatorcchb2008 yatorcchb2007 ;
	do i=1 to dim(yatorcchb);
		if yatorcchb[i]=1 then atorcchb_lastyoo=i+2006;
		if yatorcchbdec[i]=1 then atorcchb_firstyoo=2015-i;
	end;

	atorcchb_yearcount=atorcchb_lastyoo-atorcchb_firstyoo+1;

	* utilization variables;
	array util [*] atorcchb_fillperiod_2007-atorcchb_fillperiod_2014 atorcchb_clms_2007 - atorcchb_clms_2014
		atorcchb_filldays_2007-atorcchb_filldays_2014 atorcchb_pdays_2007-atorcchb_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	atorcchb_clms=sum(of atorcchb_clms_2007-atorcchb_clms_2014);
	atorcchb_filldays=sum(of atorcchb_filldays_2007-atorcchb_filldays_2014);
	atorcchb_pdays=sum(of atorcchb_pdays_2007-atorcchb_pdays_2014);

	* timing variables;
	atorcchb_minfilldt=min(of atorcchb_minfilldt_2007-atorcchb_minfilldt_2014);
	atorcchb_maxfilldt=max(of atorcchb_maxfilldt_2007-atorcchb_maxfilldt_2014);

	atorcchb_fillperiod=atorcchb_maxfilldt - atorcchb_minfilldt+1;

	atorcchb_pdayspy=atorcchb_pdays/atorcchb_yearcount;
	atorcchb_filldayspy=atorcchb_filldays/atorcchb_yearcount;
	atorcchb_clmspy=atorcchb_clms/atorcchb_yearcount;

	if first.bene_id; 
	
	drop i;
run;


* checks;
proc means data=statsaht.atorcchb_0714p; run;











