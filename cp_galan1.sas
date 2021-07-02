/*********************************************************************************************/
title1 'Drug Use for galan';

* Summary:
	XXXXX_pde1.do for each of galan, galan, meman, rivas
	•	Input: bene_ndc_totals_YYYY.dta, fdb_ndc_extract.dta, ipcYYYY.dta, snfcYYYY.dta
	•	Output: XXXXX_YYYY.dta, 0613, 0713
	o	for each of galan, galan, meman, rivas
	•	For drugs of interest, pulls users from 06-13, by NDC 
	o	NDCs determined in ndcbygname.do 
	•	Makes arrays of use to characterize use during the year. Pushes forward extra pills from early fills, the last fill of the year, IP days, and SNF days. 
	•	Makes wide file, showing days of use in each unit of time.;
	
options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
 mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/	

%include "../../../../../51866/PROGRAMS/setup.inc";
libname fdb "&datalib.Extracts/FDB/";
%partABlib(types=snf ip);
%partDlib(types=pde);
libname addrug "../../../data/aht/addrug/";

/*********** NDC Level file with galan ************/
data galan;
	set fdb.fdb_ndc_extract;

	ndcn=ndc*1;
	
	galan=(ndcn in(00054009021,00054009121,00054009221,00054013749,00115112008,00115112108,00115112208,00378272191,00378272291,00378272391,00378810491,00378810593,00378810693,00378810793,00378810891,00378811291,00555013809,00555013909,00555014009,00555102001,00555102101,00555102201,00591349630,00591349730,00591349830,10147088106,10147088206,10147088306,10147089103,10147089203,10147089303,12280029160,21695018430,21695059130,47335083583,47335083683,47335083783,50458038730,50458038830,50458038930,50458039660,50458039760,50458039860,50458049010,51079046901,51079046903,51079047001,51079047003,51079047101,51079047103,51079085201,51079085203,51079085301,51079085303,51079085401,51079085403,54868545300,55111040760,55111040860,55111040960,57237004960,57237005060,57237005160,59762000801,59762000901,59762001001,60505254206,60505254306,60505254406,63739070833,63739099933,65862045860,65862045960,65862046060,68084049211,68084049221,68084072911,68084072921,68382017714,68382017814,68382017914));

	if galan=1;
	
run;

/************* galan Pull **************/

%macro galanpull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) galan (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) addrug.galan_&prev_year.p (in=b keep=bene_id galan_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in galana;
	if _n_ ne obs then set pde&year._2a (firstobs=2 keep=srvc_dt rename=(srvc_dt=uplag_srvc_dt));
	set pde&year._2a nobs=obs;
	count+1;
run;

proc sort data=pde&year._3; by bene_id srvc_dt count; run;

data pde&year._4;
	set pde&year._3;
	by bene_id srvc_dt;
	if last.bene_id then uplag_srvc_dt=.;
	
	* adjusting doy flags so that they are the same as dougs - will make an adjusted version;
	doy_srvc_dt=intck('day',mdy(1,1,&year),srvc_dt)+1;
	doy_uplag_srvc_dt=intck('day',mdy(1,1,&year),uplag_srvc_dt)+1;
	
	extrapill_push=(doy_srvc_dt+dayssply)-doy_uplag_srvc_dt; * will be blank at the end of the year;
	if extrapill_push<0 then extrapill_push=0;
	if extrapill_push>10 then extrapill_push=10;
	* pushstock is the accumulated stock of extra pills. Capped at 10;
	pushstock=extrapill_push;
	&merge. if first.bene_id then pushstock=sum(pushstock,galan_push_&prev_year.);

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

	array galan_a [*] galan_a1-galan_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and galan=1 then galan_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=galan_clms_&year.)
	sum(dayssply)=galan_filldays_&year. min(srvc_dt)=galan_minfilldt_&year. max(srvc_dt)=galan_maxfilldt_&year.
	max(galan_a1-galan_a365 earlyfill_push lastfill_push galan)=;
run;

data pde&year._6;
	set pde&year._5;
	galan_fillperiod_&year.=max(galan_maxfilldt_&year.-galan_minfilldt_&year.+1,0);
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

	array galan_a [*] galan_a1-galan_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if galan_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the galan_a is 1, do nothing (already added it to the snf_push);
		* if the galan_a spot is empty, then filling in with snf_push;
		if snf_push>0 and galan_a[i]=. then do;
			galan_a[i]=1;
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

	array galan_a [*] galan_a1-galan_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if galan_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the galan_a is 1, do nothing (already added to the ips_push);
		* if the galan_a spot is not full then adding in the ips_push;
		if ips_push>0 and galan_a[i]=. then do;
			galan_a[i]=1;
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
	the total &year. pumption days.;

	galan_pdays_&year=max(min(sum(of galan_a1-galan_a365),365),0);

	drop galan_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data addrug.galan_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  galan_push_&year.=max(lastfill_push,inyear_push);
  if galan_push_&year.<0 then galan_push_&year.=0;
  if galan_push_&year.>90 then galan_push_&year.=90;
  keep bene_id galan:;
run;

%mend galanpull;

%galanpull(2006,2005,*,);
%galanpull(2007,2006,,*);
%galanpull(2008,2007,,*);
%galanpull(2009,2008,,*);
%galanpull(2010,2009,,*);
%galanpull(2011,2010,,*);
%galanpull(2012,2011,,*);
%galanpull(2013,2012,,*);
%galanpull(2014,2013,,*);

/************ Merge All 06-14 ***********/
data addrug.galan_0614p;
	merge addrug.galan_2006p (in=a)
				addrug.galan_2007p (in=b)
				addrug.galan_2008p (in=c)
				addrug.galan_2009p (in=d)
				addrug.galan_2010p (in=e)
				addrug.galan_2011p (in=f)
				addrug.galan_2012p (in=g)
				addrug.galan_2013p (in=h)
				addrug.galan_2014p (in=i);
	by bene_id;
	ygalan2006=a;
	ygalan2007=b;
	ygalan2008=c;
	ygalan2009=d;
	ygalan2010=e;
	ygalan2011=f;
	ygalan2012=g;
	ygalan2013=h;
	ygalan2014=i;

	* timing variables;
	array ygalan [*] ygalan2006-ygalan2014;
	array ygalandec [*] ygalan2014 ygalan2013 ygalan2012 ygalan2011 ygalan2010 ygalan2009 ygalan2008 ygalan2007 ygalan2006;
	do i=1 to dim(ygalan);
		if ygalan[i]=1 then galan_lastyoo=i+2005;
		if ygalandec[i]=1 then galan_firstyoo=2015-i;
	end;

	galan_yearcount=galan_lastyoo-galan_firstyoo+1;

	* utilization variables;
	array util [*] galan_fillperiod_2006-galan_fillperiod_2014 galan_clms_2006 - galan_clms_2014
		galan_filldays_2006-galan_filldays_2014 galan_pdays_2006-galan_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	galan_clms=sum(of galan_clms_2006-galan_clms_2014);
	galan_filldays=sum(of galan_filldays_2006-galan_filldays_2014);
	galan_pdays=sum(of galan_pdays_2006-galan_pdays_2014);

	* timing variables;
	galan_minfilldt=min(of galan_minfilldt_2006-galan_minfilldt_2014);
	galan_maxfilldt=max(of galan_maxfilldt_2006-galan_maxfilldt_2014);

	galan_fillperiod=galan_maxfilldt - galan_minfilldt+1;

	galan_pdayspy=galan_pdays/galan_yearcount;
	galan_filldayspy=galan_filldays/galan_yearcount;
	galan_clmspy=galan_clms/galan_yearcount;

	if first.bene_id; 
	
	drop i;
run;

/*********** Merge galan 07-13 **********/
data addrug.galan_0714p;
	merge addrug.galan_2007p (in=b)
				addrug.galan_2008p (in=c)
				addrug.galan_2009p (in=d)
				addrug.galan_2010p (in=e)
				addrug.galan_2011p (in=f)
				addrug.galan_2012p (in=g)
				addrug.galan_2013p (in=h)
				addrug.galan_2014p (in=i);
	by bene_id;
	ygalan2007=b;
	ygalan2008=c;
	ygalan2009=d;
	ygalan2010=e;
	ygalan2011=f;
	ygalan2012=g;
	ygalan2013=h;
	ygalan2014=i;

	* timing variables;
	array ygalan [*] ygalan2007-ygalan2014;
	array ygalandec [*] ygalan2014 ygalan2013 ygalan2012 ygalan2011 ygalan2010 ygalan2009 ygalan2008 ygalan2007 ;
	do i=1 to dim(ygalan);
		if ygalan[i]=1 then galan_lastyoo=i+2006;
		if ygalandec[i]=1 then galan_firstyoo=2015-i;
	end;

	galan_yearcount=galan_lastyoo-galan_firstyoo+1;

	* utilization variables;
	array util [*] galan_fillperiod_2007-galan_fillperiod_2014 galan_clms_2007 - galan_clms_2014
		galan_filldays_2007-galan_filldays_2014 galan_pdays_2007-galan_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	galan_clms=sum(of galan_clms_2007-galan_clms_2014);
	galan_filldays=sum(of galan_filldays_2007-galan_filldays_2014);
	galan_pdays=sum(of galan_pdays_2007-galan_pdays_2014);

	* timing variables;
	galan_minfilldt=min(of galan_minfilldt_2007-galan_minfilldt_2014);
	galan_maxfilldt=max(of galan_maxfilldt_2007-galan_maxfilldt_2014);

	galan_fillperiod=galan_maxfilldt - galan_minfilldt+1;

	galan_pdayspy=galan_pdays/galan_yearcount;
	galan_filldayspy=galan_filldays/galan_yearcount;
	galan_clmspy=galan_clms/galan_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* checks;
proc means data=addrug.galan_0614p; run;
proc means data=addrug.galan_0714p; run;











