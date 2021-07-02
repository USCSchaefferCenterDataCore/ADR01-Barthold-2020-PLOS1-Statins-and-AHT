/*********************************************************************************************/
title1 'Drug Use for Donep';

* Summary:
	XXXXX_pde1.do for each of donep, galan, meman, rivas
	•	Input: bene_ndc_totals_YYYY.dta, fdb_ndc_extract.dta, ipcYYYY.dta, snfcYYYY.dta
	•	Output: XXXXX_YYYY.dta, 0613, 0713
	o	for each of donep, galan, meman, rivas
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

/*********** NDC Level file with Donep ************/
data donep;
	set fdb.fdb_ndc_extract;

	ndcn=ndc*1;
	
	donep=(ndcn in(00093073805,00093073856,00093073898,00093073905,00093073956,00093073998,00093540765,00093540865,00143974709,00143974730,00143974809,00143974830,00228452903,00228452909,00378102577,00378102593,00378514405,00378514477,00378514493,00378514505,00378514577,00378514593,00781527410,00781527413,00781527431,00781527492,00781527510,00781527513,00781527531,00781527592,00781527664,00781527764,00904624261,00904624361,00904635461,00904635561,00904640846,00904640861,00904640880,00904640889,00904640946,00904640961,00904640980,00904640989,12280029230,12280029290,12280036715,12280036730,12280036790,13668010205,13668010210,13668010230,13668010240,13668010274,13668010290,13668010305,13668010310,13668010326,13668010330,13668010371,13668010374,13668010390,24979000406,24979000407,31722013910,31722014010,31722073705,31722073730,31722073790,31722073805,31722073830,31722073890,33342002707,33342002710,33342002715,33342002744,33342002807,33342002810,33342002815,33342002844,33342002907,33342002960,33342003007,33342003060,33342006107,33342006110,42291024690,42543070201,42543070205,42543070210,42543070230,42543070290,42543070301,42543070305,42543070310,42543070330,42543070390,43547027503,43547027509,43547027511,43547027603,43547027609,43547027611,43547038203,43547038209,45963056004,45963056008,45963056030,45963056104,45963056108,45963056130,49848000590,49848000690,49884023209,49884023211,49999075330,49999075430,49999075490,51079013830,51079013856,51079013930,51079013956,52343008930,52343008990,52343008999,52343009030,52343009090,52343009099,54868395200,54868424500,54868620700,54868620701,54868620800,55111030230,55111030290,55111035605,55111035610,55111035630,55111035690,55111035705,55111035710,55111035730,55111035790,55289015121,55289015130,58864088630,58864089530,59746032930,59746032990,59746033001,59746033030,59746033090,59762024501,59762024502,59762024503,59762024504,59762024601,59762024602,59762024603,59762024604,59762025001,59762025201,60429032110,60429032190,60429032290,60687017101,60687018201,60687018211,62332009230,62332009290,62332009291,62332009330,62332009390,62332009391,62756044018,62756044081,62756044083,62756044518,62756044581,62756044583,62856024511,62856024530,62856024541,62856024590,62856024611,62856024630,62856024641,62856024690,62856024730,62856024790,62856083130,62856083230,63304012810,63304012830,63304012877,63304012890,63304012910,63304012930,63304012977,63304012990,63629363201,63739064610,63739065210,63739065310,63739066710,63739066810,63739067810,64679031101,64679031103,64679031105,64679031201,64679031203,64679031205,65862032530,65862032590,65862032599,65862032630,65862032690,65862032699,67544009215,67544009217,67544009288,68084047701,68084047711,68084047801,68084047811,68084072501,68084072511,68084073401,68084073411,68180052706,68180052709,68382034606,68382034706,69452010813,69452010819,69452010830,69452010913,69452010919,69452010930));
	
	if donep=1;
	
run;

/************* donep Pull **************/

%macro doneppull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) donep (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) addrug.donep_&prev_year.p (in=b keep=bene_id donep_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in donepa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,donep_push_&prev_year.);

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

	array donep_a [*] donep_a1-donep_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and donep=1 then donep_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=donep_clms_&year.)
	sum(dayssply)=donep_filldays_&year. min(srvc_dt)=donep_minfilldt_&year. max(srvc_dt)=donep_maxfilldt_&year.
	max(donep_a1-donep_a365 earlyfill_push lastfill_push donep)=;
run;

data pde&year._6;
	set pde&year._5;
	donep_fillperiod_&year.=max(donep_maxfilldt_&year.-donep_minfilldt_&year.+1,0);
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

	array donep_a [*] donep_a1-donep_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if donep_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the donep_a is 1, do nothing (already added it to the snf_push);
		* if the donep_a spot is empty, then filling in with snf_push;
		if snf_push>0 and donep_a[i]=. then do;
			donep_a[i]=1;
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

	array donep_a [*] donep_a1-donep_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if donep_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the donep_a is 1, do nothing (already added to the ips_push);
		* if the donep_a spot is not full then adding in the ips_push;
		if ips_push>0 and donep_a[i]=. then do;
			donep_a[i]=1;
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

	donep_pdays_&year=max(min(sum(of donep_a1-donep_a365),365),0);

	drop donep_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data addrug.donep_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  donep_push_&year.=max(lastfill_push,inyear_push);
  if donep_push_&year.<0 then donep_push_&year.=0;
  if donep_push_&year.>90 then donep_push_&year.=90;
  keep bene_id donep:;
run;

%mend doneppull;

%doneppull(2006,2005,*,);
%doneppull(2007,2006,,*);
%doneppull(2008,2007,,*);
%doneppull(2009,2008,,*);
%doneppull(2010,2009,,*);
%doneppull(2011,2010,,*);
%doneppull(2012,2011,,*);
%doneppull(2013,2012,,*);
%doneppull(2014,2013,,*);

/************ Merge All 06-14 ***********/
data addrug.donep_0614p;
	merge addrug.donep_2006p (in=a)
				addrug.donep_2007p (in=b)
				addrug.donep_2008p (in=c)
				addrug.donep_2009p (in=d)
				addrug.donep_2010p (in=e)
				addrug.donep_2011p (in=f)
				addrug.donep_2012p (in=g)
				addrug.donep_2013p (in=h)
				addrug.donep_2014p (in=i);
	by bene_id;
	ydonep2006=a;
	ydonep2007=b;
	ydonep2008=c;
	ydonep2009=d;
	ydonep2010=e;
	ydonep2011=f;
	ydonep2012=g;
	ydonep2013=h;
	ydonep2014=i;

	* timing variables;
	array ydonep [*] ydonep2006-ydonep2014;
	array ydonepdec [*] ydonep2014 ydonep2013 ydonep2012 ydonep2011 ydonep2010 ydonep2009 ydonep2008 ydonep2007 ydonep2006;
	do i=1 to dim(ydonep);
		if ydonep[i]=1 then donep_lastyoo=i+2005;
		if ydonepdec[i]=1 then donep_firstyoo=2015-i;
	end;

	donep_yearcount=donep_lastyoo-donep_firstyoo+1;

	* utilization variables;
	array util [*] donep_fillperiod_2006-donep_fillperiod_2014 donep_clms_2006 - donep_clms_2014
		donep_filldays_2006-donep_filldays_2014 donep_pdays_2006-donep_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	donep_clms=sum(of donep_clms_2006-donep_clms_2014);
	donep_filldays=sum(of donep_filldays_2006-donep_filldays_2014);
	donep_pdays=sum(of donep_pdays_2006-donep_pdays_2014);

	* timing variables;
	donep_minfilldt=min(of donep_minfilldt_2006-donep_minfilldt_2014);
	donep_maxfilldt=max(of donep_maxfilldt_2006-donep_maxfilldt_2014);

	donep_fillperiod=donep_maxfilldt - donep_minfilldt+1;

	donep_pdayspy=donep_pdays/donep_yearcount;
	donep_filldayspy=donep_filldays/donep_yearcount;
	donep_clmspy=donep_clms/donep_yearcount;

	if first.bene_id; 
	
	drop i;
run;

/*********** Merge donep 07-13 **********/
data addrug.donep_0714p;
	merge addrug.donep_2007p (in=b)
				addrug.donep_2008p (in=c)
				addrug.donep_2009p (in=d)
				addrug.donep_2010p (in=e)
				addrug.donep_2011p (in=f)
				addrug.donep_2012p (in=g)
				addrug.donep_2013p (in=h)
				addrug.donep_2014p (in=i);
	by bene_id;
	ydonep2007=b;
	ydonep2008=c;
	ydonep2009=d;
	ydonep2010=e;
	ydonep2011=f;
	ydonep2012=g;
	ydonep2013=h;
	ydonep2014=i;

	* timing variables;
	array ydonep [*] ydonep2007-ydonep2014;
	array ydonepdec [*] ydonep2014 ydonep2013 ydonep2012 ydonep2011 ydonep2010 ydonep2009 ydonep2008 ydonep2007 ;
	do i=1 to dim(ydonep);
		if ydonep[i]=1 then donep_lastyoo=i+2006;
		if ydonepdec[i]=1 then donep_firstyoo=2015-i;
	end;

	donep_yearcount=donep_lastyoo-donep_firstyoo+1;

	* utilization variables;
	array util [*] donep_fillperiod_2007-donep_fillperiod_2014 donep_clms_2007 - donep_clms_2014
		donep_filldays_2007-donep_filldays_2014 donep_pdays_2007-donep_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	donep_clms=sum(of donep_clms_2007-donep_clms_2014);
	donep_filldays=sum(of donep_filldays_2007-donep_filldays_2014);
	donep_pdays=sum(of donep_pdays_2007-donep_pdays_2014);

	* timing variables;
	donep_minfilldt=min(of donep_minfilldt_2007-donep_minfilldt_2014);
	donep_maxfilldt=max(of donep_maxfilldt_2007-donep_maxfilldt_2014);

	donep_fillperiod=donep_maxfilldt - donep_minfilldt+1;

	donep_pdayspy=donep_pdays/donep_yearcount;
	donep_filldayspy=donep_filldays/donep_yearcount;
	donep_clmspy=donep_clms/donep_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* checks;
proc means data=addrug.donep_0614p; run;
proc means data=addrug.donep_0714p; run;











