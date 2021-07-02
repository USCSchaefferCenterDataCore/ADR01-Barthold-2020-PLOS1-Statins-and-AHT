/*********************************************************************************************/
title1 'Drug Use for simso';

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

/*********** NDC Level file with simso ************/
data simso;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	ndcn=ndc*1;
	
	sim=(ndcn in(00006054328,00006054331,00006054354,00006054361,00006054382,00006072628,00006072631,
	00006072654,00006072661,00006072682,00006073528,00006073531,00006073554,00006073561,
	00006073582,00006073587,00006074028,00006074031,00006074054,00006074061,00006074082,
	00006074087,00006074928,00006074931,00006074954,00006074961,00006074982,00093715219,
	00093715256,00093715293,00093715298,00093715310,00093715319,00093715356,00093715393,
	00093715398,00093715410,00093715419,00093715456,00093715493,00093715498,00093715510,
	00093715519,00093715556,00093715593,00093715598,00093715610,00093715619,00093715656,
	00093715693,00093715698,00247115230,00247115330,00247115360,00406206503,00406206505,
	00406206510,00406206560,00406206590,00406206603,00406206605,00406206610,00406206660,
	00406206690,00406206703,00406206705,00406206710,00406206760,00406206790,00406206803,
	00406206805,00406206810,00406206860,00406206890,00406206903,00406206905,00406206910,
	00406206960,00406206990,00440832230,00440832390,00440832490,00781507031,00781507092,
	00781507131,00781507192,00781507231,00781507292,00781507331,00781507392,00781507431,
	00781507492,00904580061,00904580161,00904580261,10135050905,10135050990,10135051005,
	10135051030,10135051090,10135051105,10135051130,10135051190,10135051205,10135051230,
	10135051290,16252050530,16252050550,16252050590,16252050630,16252050650,16252050690,
	16252050730,16252050750,16252050790,16252050830,16252050850,16252050890,16252050930,
	16252050950,16252050990,16714068101,16714068102,16714068201,16714068202,16714068203,
	16714068301,16714068302,16714068303,16714068401,16714068402,16714068403,16714068501,
	16714068502,16714068503,16729000410,16729000415,16729000417,16729000510,16729000515,
	16729000517,16729000610,16729000615,16729000617,16729000710,16729000715,16729000717,
	21695074030,23490935409,24658021010,24658021030,24658021045,24658021090,24658021110,
	24658021130,24658021145,24658021190,24658021210,24658021230,24658021245,24658021290,
	24658021310,24658021330,24658021345,24658021390,24658021410,24658021430,24658021445,
	24658021490,24658030010,24658030090,24658030110,24658030130,24658030145,24658030190,
	24658030210,24658030230,24658030245,24658030290,24658030310,24658030330,24658030345,
	24658030390,24658030410,24658030430,24658030445,24658030490,43063000801,43063008030,
	43353022845,45802009301,45802009365,45802009375,45802029265,45802029275,45802038401,
	45802038465,45802038475,45802038493,45802087901,45802087965,45802087975,45802087993,
	45802092465,49999030630,49999088930,49999088960,49999088990,49999090330,50742013710,
	50742013810,50742013910,50742014010,51079039301,51079039320,51079039801,51079039820,
	51079045401,51079045420,51079045501,51079045520,51079045601,51079045620,51079068601,
	51079068620,52959011230,54458092804,54458093210,54458093310,54458093410,54569440400,
	54569564000,54569583301,54569583302,54569583401,54868263901,54868310400,54868310401,
	54868415700,54868415701,54868418100,54868418101,54868562700,54868562701,54868562800,
	54868562801,54868562900,54868562901,54868562902,54868563000,54868563001,55111019705,
	55111019730,55111019790,55111019805,55111019830,55111019890,55111019905,55111019910,
	55111019930,55111019990,55111020005,55111020010,55111020030,55111020090,55111026805,
	55111026830,55111026890,55111072610,55111072630,55111072690,55111073510,55111073530,
	55111073590,55111074010,55111074030,55111074090,55111074910,55111074930,55111074990,
	55111075010,55111075030,55111075090,55289029314,55289029330,55289029390,55289033814,
	55289033890,55289039530,55289039590,55289087430,57866798201,57866798301,57866798601,
	58016000600,58016000700,58016000730,58016000790,58016000830,58016036530,58016036560,
	58016036590,58016038500,58016038560,58864068230,58864076030,63304078910,63304078930,
	63304078990,63304079010,63304079030,63304079090,63304079110,63304079130,63304079190,
	63304079210,63304079230,63304079290,63304079310,63304079330,63304079350,63304079390,
	63739041910,63739042010,63739042110,63739042210,63739043510,63739043610,63739043704,
	63739043710,63739043810,63739057210,63739057310,65243006515,65243006545,65243008215,
	65243008245,65243012745,65243034845,65243034945,65243036709,65243036745,65862005030,
	65862005090,65862005126,65862005130,65862005190,65862005199,65862005226,65862005230,
	65862005290,65862005299,65862005322,65862005330,65862005390,65862005399,65862005430,
	65862005439,65862005490,65862005499,66336098630,67544005145,67544008160,67544125445,
	67544125545,67544125645,68084016101,68084016111,68084016201,68084016211,68084016301,
	68084016311,68084016401,68084016411,68084016501,68084016511,68084051001,68084051101,
	68084051111,68084051201,68084051211,68084051301,68084051311,68084051401,68084051411,
	68115075930,68180047801,68180047802,68180047803,68180047901,68180047902,68180047903,
	68180048001,68180048002,68180048003,68180048101,68180048102,68180048103,68180048206,
	68180048209,68382006505,68382006506,68382006510,68382006514,68382006516,68382006605,
	68382006606,68382006610,68382006614,68382006616,68382006624,68382006705,68382006706,
	68382006710,68382006714,68382006716,68382006724,68382006805,68382006806,68382006810,
	68382006814,68382006816,68382006840,68382006905,68382006906,68382006910,68382006914,
	68382006916,68645026154,68645026254,68645026354));

	sim_c1=(ndcn in(12280018130,12280018190,12280038530,12280038590,12280038630,49999095730,49999095830,
	54569564800,54569576800,54868518700,54868518900,54868518901,54868525000,54868525900,
	54868525901,55289028030,55289052030,55289098021,66582031101,66582031128,66582031131,
	66582031154,66582031182,66582031228,66582031231,66582031254,66582031282,66582031287,
	66582031301,66582031331,66582031352,66582031354,66582031374,66582031386,66582031501,
	66582031531,66582031552,66582031554,66582031566,66582031574));

	sim_c2=(ndcn in(00074331290,00074331590,00074331690,00074345590,00074345790,00074345990,54868588600,
	54868588601,54868590400,54868590401,54868616900));

	sim_c3=(ndcn in(00006075331,00006075731,00006075754,00006075782,00006077331,00006077354,00006077382));
	
	simso=max(sim,sim_c1,sim_c2,sim_c3);
	
	if simso=1;
	
run;

proc sort data=simso; by ndc; run;
	
/************* simso Pull **************/

%macro simsopull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) simso (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) statsaht.simso_&prev_year.p (in=b keep=bene_id simso_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in simsoa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,simso_push_&prev_year.);

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

	array simso_a [*] simso_a1-simso_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and simso=1 then simso_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=simso_clms_&year.)
	sum(dayssply)=simso_filldays_&year. min(srvc_dt)=simso_minfilldt_&year. max(srvc_dt)=simso_maxfilldt_&year.
	max(simso_a1-simso_a365 earlyfill_push lastfill_push simso)=;
run;

data pde&year._6;
	set pde&year._5;
	simso_fillperiod_&year.=max(simso_maxfilldt_&year.-simso_minfilldt_&year.+1,0);
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

	array simso_a [*] simso_a1-simso_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if simso_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the simso_a is 1, do nothing (already added it to the snf_push);
		* if the simso_a spot is empty, then filling in with snf_push;
		if snf_push>0 and simso_a[i]=. then do;
			simso_a[i]=1;
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

	array simso_a [*] simso_a1-simso_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if simso_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the simso_a is 1, do nothing (already added to the ips_push);
		* if the simso_a spot is not full then adding in the ips_push;
		if ips_push>0 and simso_a[i]=. then do;
			simso_a[i]=1;
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
	
	simso_pdays_&year=max(min(sum(of simso_a1-simso_a365),365),0);

	drop simso_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data statsaht.simso_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  simso_push_&year.=max(lastfill_push,inyear_push);
  if simso_push_&year.<0 then simso_push_&year.=0;
  if simso_push_&year.>90 then simso_push_&year.=90;
  keep bene_id simso:;
run;

%mend simsopull;

%simsopull(2006,2005,*,);
%simsopull(2007,2006,,*);
%simsopull(2008,2007,,*);
%simsopull(2009,2008,,*);
%simsopull(2010,2009,,*);
%simsopull(2011,2010,,*);
%simsopull(2012,2011,,*);
%simsopull(2013,2012,,*);
%simsopull(2014,2013,,*);

/*********** Merge simso 07-13 **********/
data statsaht.simso_0714p;
	merge statsaht.simso_2007p (in=b)
				statsaht.simso_2008p (in=c)
				statsaht.simso_2009p (in=d)
				statsaht.simso_2010p (in=e)
				statsaht.simso_2011p (in=f)
				statsaht.simso_2012p (in=g)
				statsaht.simso_2013p (in=h)
				statsaht.simso_2014p (in=i);
	by bene_id;
	ysimso2007=b;
	ysimso2008=c;
	ysimso2009=d;
	ysimso2010=e;
	ysimso2011=f;
	ysimso2012=g;
	ysimso2013=h;
	ysimso2014=i;
	
	* timing variables;
	array ysimso [*] ysimso2007-ysimso2014;
	array ysimsodec [*] ysimso2014 ysimso2013 ysimso2012 ysimso2011 ysimso2010 ysimso2009 ysimso2008 ysimso2007 ;
	do i=1 to dim(ysimso);
		if ysimso[i]=1 then simso_lastyoo=i+2006;
		if ysimsodec[i]=1 then simso_firstyoo=2015-i;
	end;

	simso_yearcount=simso_lastyoo-simso_firstyoo+1;

	* utilization variables;
	array util [*] simso_fillperiod_2007-simso_fillperiod_2014 simso_clms_2007 - simso_clms_2014
		simso_filldays_2007-simso_filldays_2014 simso_pdays_2007-simso_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	simso_clms=sum(of simso_clms_2007-simso_clms_2014);
	simso_filldays=sum(of simso_filldays_2007-simso_filldays_2014);
	simso_pdays=sum(of simso_pdays_2007-simso_pdays_2014);

	* timing variables;
	simso_minfilldt=min(of simso_minfilldt_2007-simso_minfilldt_2014);
	simso_maxfilldt=max(of simso_maxfilldt_2007-simso_maxfilldt_2014);

	simso_fillperiod=simso_maxfilldt - simso_minfilldt+1;

	simso_pdayspy=simso_pdays/simso_yearcount;
	simso_filldayspy=simso_filldays/simso_yearcount;
	simso_clmspy=simso_clms/simso_yearcount;

	if first.bene_id; 
	
	drop i;
run;


* checks;
proc means data=statsaht.simso_0714p; run;











