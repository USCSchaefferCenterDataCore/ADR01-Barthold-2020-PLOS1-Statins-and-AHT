/*********************************************************************************************/
title1 'Drug Use for meman';

* Summary:
	XXXXX_pde1.do for each of meman, galan, meman, rivas
	•	Input: bene_ndc_totals_YYYY.dta, fdb_ndc_extract.dta, ipcYYYY.dta, snfcYYYY.dta
	•	Output: XXXXX_YYYY.dta, 0613, 0713
	o	for each of meman, galan, meman, rivas
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

/*********** NDC Level file with meman ************/
data meman;
	set fdb.fdb_ndc_extract;

	ndcn=ndc*1;
	
	meman=(ndcn in(00378110391,00378110491,00456320014,00456320212,00456320511,00456320560,00456320563,00456321011,00456321060,00456321063,00456340029,00456340733,00456341411,00456341433,00456341463,00456341490,00456342133,00456342833,00456342863,00456342890,00527194313,00591387044,00591387045,00591387060,00591387544,00591387545,00591387560,00591390087,00832111260,00832111360,00904650561,00904650661,12280028460,12280038160,13668022260,13668022360,16590076915,21695016930,21695016960,21695023215,21695023260,27241007006,27241007106,29300017105,29300017116,29300017205,29300017216,33342029709,33342029809,33342029815,35356010560,39328055112,42291055160,42291055260,42292000501,42292000506,42292000601,42292000606,47335032186,47335032213,47335032286,49848000360,49848000460,49999080430,49999080460,53746016930,53746017360,54868516100,54868565400,55111059660,55111059705,55111059760,55289093730,55289093760,58864088730,60687017311,60687017357,60687018411,60687018457,62332007560,62332007591,62332007642,62332007660,64679012102,64679012103,64679012202,64679012203,65862065260,65862065360,65862065399,66105065003,66105065103,68180022907,68180023007));

	if meman=1;
	
run;

/************* meman Pull **************/

%macro memanpull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) meman (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) addrug.meman_&prev_year.p (in=b keep=bene_id meman_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in memana;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,meman_push_&prev_year.);

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

	array meman_a [*] meman_a1-meman_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and meman=1 then meman_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=meman_clms_&year.)
	sum(dayssply)=meman_filldays_&year. min(srvc_dt)=meman_minfilldt_&year. max(srvc_dt)=meman_maxfilldt_&year.
	max(meman_a1-meman_a365 earlyfill_push lastfill_push meman)=;
run;

data pde&year._6;
	set pde&year._5;
	meman_fillperiod_&year.=max(meman_maxfilldt_&year.-meman_minfilldt_&year.+1,0);
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

	array meman_a [*] meman_a1-meman_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if meman_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the meman_a is 1, do nothing (already added it to the snf_push);
		* if the meman_a spot is empty, then filling in with snf_push;
		if snf_push>0 and meman_a[i]=. then do;
			meman_a[i]=1;
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

	array meman_a [*] meman_a1-meman_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if meman_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the meman_a is 1, do nothing (already added to the ips_push);
		* if the meman_a spot is not full then adding in the ips_push;
		if ips_push>0 and meman_a[i]=. then do;
			meman_a[i]=1;
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

	meman_pdays_&year=max(min(sum(of meman_a1-meman_a365),365),0);

	drop meman_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data addrug.meman_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  meman_push_&year.=max(lastfill_push,inyear_push);
  if meman_push_&year.<0 then meman_push_&year.=0;
  if meman_push_&year.>90 then meman_push_&year.=90;
  keep bene_id meman:;
run;

%mend memanpull;

%memanpull(2006,2005,*,);
%memanpull(2007,2006,,*);
%memanpull(2008,2007,,*);
%memanpull(2009,2008,,*);
%memanpull(2010,2009,,*);
%memanpull(2011,2010,,*);
%memanpull(2012,2011,,*);
%memanpull(2013,2012,,*);
%memanpull(2014,2013,,*);

/************ Merge All 06-14 ***********/
data addrug.meman_0614p;
	merge addrug.meman_2006p (in=a)
				addrug.meman_2007p (in=b)
				addrug.meman_2008p (in=c)
				addrug.meman_2009p (in=d)
				addrug.meman_2010p (in=e)
				addrug.meman_2011p (in=f)
				addrug.meman_2012p (in=g)
				addrug.meman_2013p (in=h)
				addrug.meman_2014p (in=i);
	by bene_id;
	ymeman2006=a;
	ymeman2007=b;
	ymeman2008=c;
	ymeman2009=d;
	ymeman2010=e;
	ymeman2011=f;
	ymeman2012=g;
	ymeman2013=h;
	ymeman2014=i;

	* timing variables;
	array ymeman [*] ymeman2006-ymeman2014;
	array ymemandec [*] ymeman2014 ymeman2013 ymeman2012 ymeman2011 ymeman2010 ymeman2009 ymeman2008 ymeman2007 ymeman2006;
	do i=1 to dim(ymeman);
		if ymeman[i]=1 then meman_lastyoo=i+2005;
		if ymemandec[i]=1 then meman_firstyoo=2015-i;
	end;

	meman_yearcount=meman_lastyoo-meman_firstyoo+1;

	* utilization variables;
	array util [*] meman_fillperiod_2006-meman_fillperiod_2014 meman_clms_2006 - meman_clms_2014
		meman_filldays_2006-meman_filldays_2014 meman_pdays_2006-meman_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	meman_clms=sum(of meman_clms_2006-meman_clms_2014);
	meman_filldays=sum(of meman_filldays_2006-meman_filldays_2014);
	meman_pdays=sum(of meman_pdays_2006-meman_pdays_2014);

	* timing variables;
	meman_minfilldt=min(of meman_minfilldt_2006-meman_minfilldt_2014);
	meman_maxfilldt=max(of meman_maxfilldt_2006-meman_maxfilldt_2014);

	meman_fillperiod=meman_maxfilldt - meman_minfilldt+1;

	meman_pdayspy=meman_pdays/meman_yearcount;
	meman_filldayspy=meman_filldays/meman_yearcount;
	meman_clmspy=meman_clms/meman_yearcount;

	if first.bene_id; 
	
	drop i;
run;

/*********** Merge meman 07-13 **********/
data addrug.meman_0714p;
	merge addrug.meman_2007p (in=b)
				addrug.meman_2008p (in=c)
				addrug.meman_2009p (in=d)
				addrug.meman_2010p (in=e)
				addrug.meman_2011p (in=f)
				addrug.meman_2012p (in=g)
				addrug.meman_2013p (in=h)
				addrug.meman_2014p (in=i);
	by bene_id;
	ymeman2007=b;
	ymeman2008=c;
	ymeman2009=d;
	ymeman2010=e;
	ymeman2011=f;
	ymeman2012=g;
	ymeman2013=h;
	ymeman2014=i;

	* timing variables;
	array ymeman [*] ymeman2007-ymeman2014;
	array ymemandec [*] ymeman2014 ymeman2013 ymeman2012 ymeman2011 ymeman2010 ymeman2009 ymeman2008 ymeman2007 ;
	do i=1 to dim(ymeman);
		if ymeman[i]=1 then meman_lastyoo=i+2006;
		if ymemandec[i]=1 then meman_firstyoo=2015-i;
	end;

	meman_yearcount=meman_lastyoo-meman_firstyoo+1;

	* utilization variables;
	array util [*] meman_fillperiod_2007-meman_fillperiod_2014 meman_clms_2007 - meman_clms_2014
		meman_filldays_2007-meman_filldays_2014 meman_pdays_2007-meman_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	meman_clms=sum(of meman_clms_2007-meman_clms_2014);
	meman_filldays=sum(of meman_filldays_2007-meman_filldays_2014);
	meman_pdays=sum(of meman_pdays_2007-meman_pdays_2014);

	* timing variables;
	meman_minfilldt=min(of meman_minfilldt_2007-meman_minfilldt_2014);
	meman_maxfilldt=max(of meman_maxfilldt_2007-meman_maxfilldt_2014);

	meman_fillperiod=meman_maxfilldt - meman_minfilldt+1;

	meman_pdayspy=meman_pdays/meman_yearcount;
	meman_filldayspy=meman_filldays/meman_yearcount;
	meman_clmspy=meman_clms/meman_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* checks;
proc means data=addrug.meman_0614p; run;
proc means data=addrug.meman_0714p; run;











