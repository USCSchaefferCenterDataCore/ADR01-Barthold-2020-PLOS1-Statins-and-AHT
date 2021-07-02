/*********************************************************************************************/
title1 'Drug Use for praso';

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

/*********** NDC Level file with praso ************/
data praso;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	ndcn=ndc*1;
	
	pra=(ndcn in(00003515405,00003517805,00003517806,00003517875,00003519410,00003519433,00003519510,
	00003519533,00093077110,00093077198,00093720110,00093720198,00093720210,00093720298,
	00093727010,00093727098,00247113930,00247114030,00247114060,00247127630,00378055277,
	00378055377,00378055477,00378055777,00378821010,00378821077,00378822010,00378822077,
	00378824010,00378824077,00378828005,00378828077,00440815730,00440815890,00591001310,
	00591001319,00591001410,00591001419,00591001610,00591001619,00591001905,00591001919,
	00781523110,00781523192,00781523210,00781523292,00781523410,00781523492,00904589161,
	00904589261,00904589361,00904611361,00904611461,00904611561,10135049890,10135049990,
	10135050090,12280033530,12280033590,16252052690,16252052750,16252052790,16252052850,
	16252052890,16252052990,21695017830,21695017990,23490935206,43063014330,43063019530,
	49884017609,49884017610,49884017909,49884017910,49884018009,49884018010,50111076117,
	50111076203,50111076217,50111076403,50111076417,51079045801,51079045820,51079078201,
	51079078220,54458090802,54458092510,54458092610,54458092710,54458098507,54458098510,
	54458098610,54458098709,54569461000,54569579300,54569579400,54569579401,54868327000,
	54868327002,54868463400,54868557600,54868557700,54868557800,54868557801,55111022905,
	55111022990,55111023005,55111023090,55111023105,55111023190,55111027405,55111027490,
	55289087130,55887019230,58016001200,58016001230,58016001300,58016001330,58864074330,
	60429036905,60505016805,60505016809,60505016907,60505016909,60505017007,60505017008,
	60505017009,60505132305,60505132309,63304059590,63304059690,63304059790,63304059805,
	63304059890,68084018601,68084018701,68084018711,68084018801,68084018811,68084050001,
	68084050011,68084050101,68084050111,68084050201,68084050211,68115066490,68180048502,
	68180048509,68180048602,68180048609,68180048702,68180048709,68180048802,68180048809,
	68382007005,68382007016,68382007105,68382007116,68382007205,68382007216,68382007305,
	68382007316,68462019505,68462019590,68462019605,68462019690,68462019705,68462019790,
	68462019805,68462019890));

	pra_c1=(ndcn in(00003517311,00003518311));
	
	praso=max(pra,pra_c1);
		
	if praso=1;
	
run;

proc sort data=praso; by ndc; run;
	
/************* praso Pull **************/

%macro prasopull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) praso (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) statsaht.praso_&prev_year.p (in=b keep=bene_id praso_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in prasoa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,praso_push_&prev_year.);

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

	array praso_a [*] praso_a1-praso_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and praso=1 then praso_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=praso_clms_&year.)
	sum(dayssply)=praso_filldays_&year. min(srvc_dt)=praso_minfilldt_&year. max(srvc_dt)=praso_maxfilldt_&year.
	max(praso_a1-praso_a365 earlyfill_push lastfill_push praso)=;
run;

data pde&year._6;
	set pde&year._5;
	praso_fillperiod_&year.=max(praso_maxfilldt_&year.-praso_minfilldt_&year.+1,0);
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

	array praso_a [*] praso_a1-praso_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if praso_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the praso_a is 1, do nothing (already added it to the snf_push);
		* if the praso_a spot is empty, then filling in with snf_push;
		if snf_push>0 and praso_a[i]=. then do;
			praso_a[i]=1;
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

	array praso_a [*] praso_a1-praso_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if praso_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the praso_a is 1, do nothing (already added to the ips_push);
		* if the praso_a spot is not full then adding in the ips_push;
		if ips_push>0 and praso_a[i]=. then do;
			praso_a[i]=1;
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
	
	praso_pdays_&year=max(min(sum(of praso_a1-praso_a365),365),0);

	drop praso_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data statsaht.praso_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  praso_push_&year.=max(lastfill_push,inyear_push);
  if praso_push_&year.<0 then praso_push_&year.=0;
  if praso_push_&year.>90 then praso_push_&year.=90;
  keep bene_id praso:;
run;

%mend prasopull;

%prasopull(2006,2005,*,);
%prasopull(2007,2006,,*);
%prasopull(2008,2007,,*);
%prasopull(2009,2008,,*);
%prasopull(2010,2009,,*);
%prasopull(2011,2010,,*);
%prasopull(2012,2011,,*);
%prasopull(2013,2012,,*);
%prasopull(2014,2013,,*);

/*********** Merge praso 07-13 **********/
data statsaht.praso_0714p;
	merge statsaht.praso_2007p (in=b)
				statsaht.praso_2008p (in=c)
				statsaht.praso_2009p (in=d)
				statsaht.praso_2010p (in=e)
				statsaht.praso_2011p (in=f)
				statsaht.praso_2012p (in=g)
				statsaht.praso_2013p (in=h)
				statsaht.praso_2014p (in=i);
	by bene_id;
	ypraso2007=b;
	ypraso2008=c;
	ypraso2009=d;
	ypraso2010=e;
	ypraso2011=f;
	ypraso2012=g;
	ypraso2013=h;
	ypraso2014=i;
	
	* timing variables;
	array ypraso [*] ypraso2007-ypraso2014;
	array yprasodec [*] ypraso2014 ypraso2013 ypraso2012 ypraso2011 ypraso2010 ypraso2009 ypraso2008 ypraso2007 ;
	do i=1 to dim(ypraso);
		if ypraso[i]=1 then praso_lastyoo=i+2006;
		if yprasodec[i]=1 then praso_firstyoo=2015-i;
	end;

	praso_yearcount=praso_lastyoo-praso_firstyoo+1;

	* utilization variables;
	array util [*] praso_fillperiod_2007-praso_fillperiod_2014 praso_clms_2007 - praso_clms_2014
		praso_filldays_2007-praso_filldays_2014 praso_pdays_2007-praso_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	praso_clms=sum(of praso_clms_2007-praso_clms_2014);
	praso_filldays=sum(of praso_filldays_2007-praso_filldays_2014);
	praso_pdays=sum(of praso_pdays_2007-praso_pdays_2014);

	* timing variables;
	praso_minfilldt=min(of praso_minfilldt_2007-praso_minfilldt_2014);
	praso_maxfilldt=max(of praso_maxfilldt_2007-praso_maxfilldt_2014);

	praso_fillperiod=praso_maxfilldt - praso_minfilldt+1;

	praso_pdayspy=praso_pdays/praso_yearcount;
	praso_filldayspy=praso_filldays/praso_yearcount;
	praso_clmspy=praso_clms/praso_yearcount;

	if first.bene_id; 
	
	drop i;
run;


* checks;
proc means data=statsaht.praso_0714p; run;











