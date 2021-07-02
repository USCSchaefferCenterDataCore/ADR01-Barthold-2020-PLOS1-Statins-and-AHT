/*********************************************************************************************/
title1 'Drug Use for rivas';

* Summary:
	XXXXX_pde1.do for each of rivas, galan, meman, rivas
	•	Input: bene_ndc_totals_YYYY.dta, fdb_ndc_extract.dta, ipcYYYY.dta, snfcYYYY.dta
	•	Output: XXXXX_YYYY.dta, 0613, 0713
	o	for each of rivas, galan, meman, rivas
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

/*********** NDC Level file with rivas ************/
data rivas;
	set fdb.fdb_ndc_extract;

	ndcn=ndc*1;
	
	rivas=(ndcn in(00078032306,00078032315,00078032344,00078032361,00078032406,00078032415,00078032444,00078032506,00078032515,00078032544,00078032606,00078032615,00078032644,00078033931,00078050115,00078050161,00078050215,00078050261,00078050315,00078050361,00591320860,00591320960,00591321060,00591321160,00781261413,00781261460,00781261513,00781261560,00781261613,00781261660,00781261713,00781261760,00781730431,00781730458,00781730931,00781731331,06808405501,12280038960,21695035730,33342008909,33342008915,33342009009,33342009015,33342009109,33342009115,33342009209,33342009215,35356039430,47781030403,47781030503,47781040503,51991079306,51991079406,51991079506,51991079606,54868451200,54868451201,54868524000,54868533900,54868583900,54868595400,54868607000,54868614500,55111035205,55111035260,55111035305,55111035360,55111035405,55111035460,55111035505,55111035560,60429039660,60505322006,60505322106,60505322206,60505322306,62756014513,62756014586,62756014613,62756014686,62756014713,62756014786,62756014813,62756014886,63739057610,63739057710,63739057810,63739057910,68084055001,68084055011));
	
	if rivas=1;
	
run;

/************* rivas Pull **************/

proc sort data=rivas; by ndc; run;

%macro rivaspull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) rivas (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) addrug.rivas_&prev_year.p (in=b keep=bene_id rivas_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in rivasa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,rivas_push_&prev_year.);

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

	array rivas_a [*] rivas_a1-rivas_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and rivas=1 then rivas_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=rivas_clms_&year.)
	sum(dayssply)=rivas_filldays_&year. min(srvc_dt)=rivas_minfilldt_&year. max(srvc_dt)=rivas_maxfilldt_&year.
	max(rivas_a1-rivas_a365 earlyfill_push lastfill_push rivas)=;
run;

data pde&year._6;
	set pde&year._5;
	rivas_fillperiod_&year.=max(rivas_maxfilldt_&year.-rivas_minfilldt_&year.+1,0);
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

	array rivas_a [*] rivas_a1-rivas_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if rivas_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the rivas_a is 1, do nothing (already added it to the snf_push);
		* if the rivas_a spot is empty, then filling in with snf_push;
		if snf_push>0 and rivas_a[i]=. then do;
			rivas_a[i]=1;
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

	array rivas_a [*] rivas_a1-rivas_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if rivas_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the rivas_a is 1, do nothing (already added to the ips_push);
		* if the rivas_a spot is not full then adding in the ips_push;
		if ips_push>0 and rivas_a[i]=. then do;
			rivas_a[i]=1;
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

	rivas_pdays_&year=max(min(sum(of rivas_a1-rivas_a365),365),0);

	drop rivas_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data addrug.rivas_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  rivas_push_&year.=max(lastfill_push,inyear_push);
  if rivas_push_&year.<0 then rivas_push_&year.=0;
  if rivas_push_&year.>90 then rivas_push_&year.=90;
  keep bene_id rivas:;
run;

%mend rivaspull;

%rivaspull(2006,2005,*,);
%rivaspull(2007,2006,,*);
%rivaspull(2008,2007,,*);
%rivaspull(2009,2008,,*);
%rivaspull(2010,2009,,*);
%rivaspull(2011,2010,,*);
%rivaspull(2012,2011,,*);
%rivaspull(2013,2012,,*);
%rivaspull(2014,2013,,*);

/************ Merge All 06-14 ***********/
data addrug.rivas_0614p;
	merge addrug.rivas_2006p (in=a)
				addrug.rivas_2007p (in=b)
				addrug.rivas_2008p (in=c)
				addrug.rivas_2009p (in=d)
				addrug.rivas_2010p (in=e)
				addrug.rivas_2011p (in=f)
				addrug.rivas_2012p (in=g)
				addrug.rivas_2013p (in=h)
				addrug.rivas_2014p (in=i);
	by bene_id;
	yrivas2006=a;
	yrivas2007=b;
	yrivas2008=c;
	yrivas2009=d;
	yrivas2010=e;
	yrivas2011=f;
	yrivas2012=g;
	yrivas2013=h;
	yrivas2014=i;

	* timing variables;
	array yrivas [*] yrivas2006-yrivas2014;
	array yrivasdec [*] yrivas2014 yrivas2013 yrivas2012 yrivas2011 yrivas2010 yrivas2009 yrivas2008 yrivas2007 yrivas2006;
	do i=1 to dim(yrivas);
		if yrivas[i]=1 then rivas_lastyoo=i+2005;
		if yrivasdec[i]=1 then rivas_firstyoo=2015-i;
	end;

	rivas_yearcount=rivas_lastyoo-rivas_firstyoo+1;

	* utilization variables;
	array util [*] rivas_fillperiod_2006-rivas_fillperiod_2014 rivas_clms_2006 - rivas_clms_2014
		rivas_filldays_2006-rivas_filldays_2014 rivas_pdays_2006-rivas_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	rivas_clms=sum(of rivas_clms_2006-rivas_clms_2014);
	rivas_filldays=sum(of rivas_filldays_2006-rivas_filldays_2014);
	rivas_pdays=sum(of rivas_pdays_2006-rivas_pdays_2014);

	* timing variables;
	rivas_minfilldt=min(of rivas_minfilldt_2006-rivas_minfilldt_2014);
	rivas_maxfilldt=max(of rivas_maxfilldt_2006-rivas_maxfilldt_2014);

	rivas_fillperiod=rivas_maxfilldt - rivas_minfilldt+1;

	rivas_pdayspy=rivas_pdays/rivas_yearcount;
	rivas_filldayspy=rivas_filldays/rivas_yearcount;
	rivas_clmspy=rivas_clms/rivas_yearcount;

	if first.bene_id; 
	
	drop i;
run;

/*********** Merge rivas 07-13 **********/
data addrug.rivas_0714p;
	merge addrug.rivas_2007p (in=b)
				addrug.rivas_2008p (in=c)
				addrug.rivas_2009p (in=d)
				addrug.rivas_2010p (in=e)
				addrug.rivas_2011p (in=f)
				addrug.rivas_2012p (in=g)
				addrug.rivas_2013p (in=h)
				addrug.rivas_2014p (in=i);
	by bene_id;
	yrivas2007=b;
	yrivas2008=c;
	yrivas2009=d;
	yrivas2010=e;
	yrivas2011=f;
	yrivas2012=g;
	yrivas2013=h;
	yrivas2014=i;

	* timing variables;
	array yrivas [*] yrivas2007-yrivas2014;
	array yrivasdec [*] yrivas2014 yrivas2013 yrivas2012 yrivas2011 yrivas2010 yrivas2009 yrivas2008 yrivas2007 ;
	do i=1 to dim(yrivas);
		if yrivas[i]=1 then rivas_lastyoo=i+2006;
		if yrivasdec[i]=1 then rivas_firstyoo=2015-i;
	end;

	rivas_yearcount=rivas_lastyoo-rivas_firstyoo+1;

	* utilization variables;
	array util [*] rivas_fillperiod_2007-rivas_fillperiod_2014 rivas_clms_2007 - rivas_clms_2014
		rivas_filldays_2007-rivas_filldays_2014 rivas_pdays_2007-rivas_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	rivas_clms=sum(of rivas_clms_2007-rivas_clms_2014);
	rivas_filldays=sum(of rivas_filldays_2007-rivas_filldays_2014);
	rivas_pdays=sum(of rivas_pdays_2007-rivas_pdays_2014);

	* timing variables;
	rivas_minfilldt=min(of rivas_minfilldt_2007-rivas_minfilldt_2014);
	rivas_maxfilldt=max(of rivas_maxfilldt_2007-rivas_maxfilldt_2014);

	rivas_fillperiod=rivas_maxfilldt - rivas_minfilldt+1;

	rivas_pdayspy=rivas_pdays/rivas_yearcount;
	rivas_filldayspy=rivas_filldays/rivas_yearcount;
	rivas_clmspy=rivas_clms/rivas_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* checks;
proc means data=addrug.rivas_0614p; run;
proc means data=addrug.rivas_0714p; run;











