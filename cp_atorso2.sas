/*********************************************************************************************/
title1 'Drug Use for atorso';

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

/*********** NDC Level file with atorso ************/
data atorso;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	ndcn=ndc*1;
	
	atorso=(ndcn in(00071015523,00071015534,00071015540,00071015623,00071015640,00071015694,00071015723,
	00071015740,00071015773,00071015788,00071015823,00071015873,00071015888,00071015892,
	00378201505,00378201577,00378201705,00378201777,00378212105,00378212177,00378212205,
	00378212277,00591377410,00591377419,00591377510,00591377519,00591377605,00591377619,
	00591377705,00591377719,00781538192,00781538292,00781538492,00781538892,00904629061,
	00904629161,33358021090,49999039230,49999039290,49999046730,49999046790,49999046830,
	49999046890,49999088230,49999088290,51079040901,51079040920,51079041020,51079041101,
	51079041120,51079041201,51079041203,52959004630,52959075990,52959076090,54569446600,
	54569446601,54569446700,54569458700,54569458701,54569538200,54569628300,54868393400,
	54868393401,54868393402,54868394600,54868394601,54868394602,54868394603,54868422900,
	54868422901,54868422902,54868493400,54868493401,54868632200,55111012105,55111012190,
	55111012205,55111012290,55111012305,55111012390,55111012405,55111012490,55289080030,
	55289086130,55289087030,55887062490,55887092990,57866861501,58864060830,58864062315,
	58864062330,58864068530,58864083430,60505257808,60505257809,60505257908,60505257909,
	60505258008,60505258009,60505267108,60505267109,63304082705,63304082790,63304082805,
	63304082890,63304082905,63304082990,63304083005,63304083090,66116027630,67544006030,
	67544024730,68030861501,68084056401,68084056411,68084056501,68084056511,68084058901,
	68084058911,68084059025,68115049430,68115049460,68115066815,68115066830,68115066890,
	68115080090,68115083630,68115083690,68258104001,68258600009,68258600209,68258900101,
	68258915401));

	if atorso=1;
	
run;

proc sort data=atorso; by ndc; run;
	
/************* atorso Pull **************/

%macro atorsopull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) atorso (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) statsaht.atorso_&prev_year.p (in=b keep=bene_id atorso_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in atorsoa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,atorso_push_&prev_year.);

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

	array atorso_a [*] atorso_a1-atorso_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and atorso=1 then atorso_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=atorso_clms_&year.)
	sum(dayssply)=atorso_filldays_&year. min(srvc_dt)=atorso_minfilldt_&year. max(srvc_dt)=atorso_maxfilldt_&year.
	max(atorso_a1-atorso_a365 earlyfill_push lastfill_push atorso)=;
run;

data pde&year._6;
	set pde&year._5;
	atorso_fillperiod_&year.=max(atorso_maxfilldt_&year.-atorso_minfilldt_&year.+1,0);
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

	array atorso_a [*] atorso_a1-atorso_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if atorso_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the atorso_a is 1, do nothing (already added it to the snf_push);
		* if the atorso_a spot is empty, then filling in with snf_push;
		if snf_push>0 and atorso_a[i]=. then do;
			atorso_a[i]=1;
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

	array atorso_a [*] atorso_a1-atorso_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if atorso_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the atorso_a is 1, do nothing (already added to the ips_push);
		* if the atorso_a spot is not full then adding in the ips_push;
		if ips_push>0 and atorso_a[i]=. then do;
			atorso_a[i]=1;
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
	
	atorso_pdays_&year=max(min(sum(of atorso_a1-atorso_a365),365),0);

	drop atorso_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data statsaht.atorso_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  atorso_push_&year.=max(lastfill_push,inyear_push);
  if atorso_push_&year.<0 then atorso_push_&year.=0;
  if atorso_push_&year.>90 then atorso_push_&year.=90;
  keep bene_id atorso:;
run;

%mend atorsopull;

%atorsopull(2006,2005,*,);
%atorsopull(2007,2006,,*);
%atorsopull(2008,2007,,*);
%atorsopull(2009,2008,,*);
%atorsopull(2010,2009,,*);
%atorsopull(2011,2010,,*);
%atorsopull(2012,2011,,*);
%atorsopull(2013,2012,,*);
%atorsopull(2014,2013,,*);

/*********** Merge atorso 07-13 **********/
data statsaht.atorso_0714p;
	merge statsaht.atorso_2007p (in=b)
				statsaht.atorso_2008p (in=c)
				statsaht.atorso_2009p (in=d)
				statsaht.atorso_2010p (in=e)
				statsaht.atorso_2011p (in=f)
				statsaht.atorso_2012p (in=g)
				statsaht.atorso_2013p (in=h)
				statsaht.atorso_2014p (in=i);
	by bene_id;
	yatorso2007=b;
	yatorso2008=c;
	yatorso2009=d;
	yatorso2010=e;
	yatorso2011=f;
	yatorso2012=g;
	yatorso2013=h;
	yatorso2014=i;
	
	* timing variables;
	array yatorso [*] yatorso2007-yatorso2014;
	array yatorsodec [*] yatorso2014 yatorso2013 yatorso2012 yatorso2011 yatorso2010 yatorso2009 yatorso2008 yatorso2007 ;
	do i=1 to dim(yatorso);
		if yatorso[i]=1 then atorso_lastyoo=i+2006;
		if yatorsodec[i]=1 then atorso_firstyoo=2015-i;
	end;

	atorso_yearcount=atorso_lastyoo-atorso_firstyoo+1;

	* utilization variables;
	array util [*] atorso_fillperiod_2007-atorso_fillperiod_2014 atorso_clms_2007 - atorso_clms_2014
		atorso_filldays_2007-atorso_filldays_2014 atorso_pdays_2007-atorso_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	atorso_clms=sum(of atorso_clms_2007-atorso_clms_2014);
	atorso_filldays=sum(of atorso_filldays_2007-atorso_filldays_2014);
	atorso_pdays=sum(of atorso_pdays_2007-atorso_pdays_2014);

	* timing variables;
	atorso_minfilldt=min(of atorso_minfilldt_2007-atorso_minfilldt_2014);
	atorso_maxfilldt=max(of atorso_maxfilldt_2007-atorso_maxfilldt_2014);

	atorso_fillperiod=atorso_maxfilldt - atorso_minfilldt+1;

	atorso_pdayspy=atorso_pdays/atorso_yearcount;
	atorso_filldayspy=atorso_filldays/atorso_yearcount;
	atorso_clmspy=atorso_clms/atorso_yearcount;

	if first.bene_id; 
	
	drop i;
run;


* checks;
proc means data=statsaht.atorso_0714p; run;











