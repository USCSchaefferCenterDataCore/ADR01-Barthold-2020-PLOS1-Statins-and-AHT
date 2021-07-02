/*********************************************************************************************/
title1 'Drug Use for rosuso';

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

/*********** NDC Level file with rosuso ************/
data rosuso;
	set fdb.fdb_ndc_extract (keep=ndc hic3_desc ahfs_desc);

	ndcn=ndc*1;
	
	rosuso=(ndcn in(00310075139,00310075190,00310075239,00310075290,00310075430,00310075590,12280016415,
	12280016490,12280035130,12280035190,35356041330,43353003160,49999087330,49999087390,
	49999099290,54569560000,54569567200,54569574600,54868189000,54868189001,54868496300,
	54868496301,54868496302,54868496303,54868508500,54868508501,54868508502,54868508503,
	54868534100,55289093230,55289093530,58016003700,58016003730,58016003760,58016003790,
	58016005200,58016005230,58016005260,58016005290,58016007100,58016007130,68071078430));

	if rosuso=1;
	
run;

proc sort data=rosuso; by ndc; run;
	
/************* rosuso Pull **************/

%macro rosusopull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data pde&year.;
	set pde.opt1pde&year (keep=bene_id srvc_dt prdsrvid dayssply);
	rename prdsrvid=ndc;
run;

proc sort data=pde&year.; by ndc; run;

data pde&year._1;
	merge pde&year. (in=a) rosuso (in=b);
	by ndc;
	if a and b;
run;

proc sort data=pde&year._1; by bene_id; run;

data pde&year._2;
	&set. set pde&year._1;
	&merge. merge pde&year._1 (in=a) statsaht.rosuso_&prev_year.p (in=b keep=bene_id rosuso_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in rosusoa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,rosuso_push_&prev_year.);

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

	array rosuso_a [*] rosuso_a1-rosuso_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i <= sum(doy_srvc_dt,dayssply2) and rosuso=1 then rosuso_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=pde&year._4 nway noprint;
	class bene_id;
	output out=pde&year._5 (drop=_type_ rename=_freq_=rosuso_clms_&year.)
	sum(dayssply)=rosuso_filldays_&year. min(srvc_dt)=rosuso_minfilldt_&year. max(srvc_dt)=rosuso_maxfilldt_&year.
	max(rosuso_a1-rosuso_a365 earlyfill_push lastfill_push rosuso)=;
run;

data pde&year._6;
	set pde&year._5;
	rosuso_fillperiod_&year.=max(rosuso_maxfilldt_&year.-rosuso_minfilldt_&year.+1,0);
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

	array rosuso_a [*] rosuso_a1-rosuso_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if rosuso_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the rosuso_a is 1, do nothing (already added it to the snf_push);
		* if the rosuso_a spot is empty, then filling in with snf_push;
		if snf_push>0 and rosuso_a[i]=. then do;
			rosuso_a[i]=1;
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

	array rosuso_a [*] rosuso_a1-rosuso_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if rosuso_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the rosuso_a is 1, do nothing (already added to the ips_push);
		* if the rosuso_a spot is not full then adding in the ips_push;
		if ips_push>0 and rosuso_a[i]=. then do;
			rosuso_a[i]=1;
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
	
	rosuso_pdays_&year=max(min(sum(of rosuso_a1-rosuso_a365),365),0);

	drop rosuso_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data statsaht.rosuso_&year.p;
	set pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  rosuso_push_&year.=max(lastfill_push,inyear_push);
  if rosuso_push_&year.<0 then rosuso_push_&year.=0;
  if rosuso_push_&year.>90 then rosuso_push_&year.=90;
  keep bene_id rosuso:;
run;

%mend rosusopull;

%rosusopull(2006,2005,*,);
%rosusopull(2007,2006,,*);
%rosusopull(2008,2007,,*);
%rosusopull(2009,2008,,*);
%rosusopull(2010,2009,,*);
%rosusopull(2011,2010,,*);
%rosusopull(2012,2011,,*);
%rosusopull(2013,2012,,*);
%rosusopull(2014,2013,,*);

/*********** Merge rosuso 07-13 **********/
data statsaht.rosuso_0714p;
	merge statsaht.rosuso_2007p (in=b)
				statsaht.rosuso_2008p (in=c)
				statsaht.rosuso_2009p (in=d)
				statsaht.rosuso_2010p (in=e)
				statsaht.rosuso_2011p (in=f)
				statsaht.rosuso_2012p (in=g)
				statsaht.rosuso_2013p (in=h)
				statsaht.rosuso_2014p (in=i);
	by bene_id;
	yrosuso2007=b;
	yrosuso2008=c;
	yrosuso2009=d;
	yrosuso2010=e;
	yrosuso2011=f;
	yrosuso2012=g;
	yrosuso2013=h;
	yrosuso2014=i;
	
	* timing variables;
	array yrosuso [*] yrosuso2007-yrosuso2014;
	array yrosusodec [*] yrosuso2014 yrosuso2013 yrosuso2012 yrosuso2011 yrosuso2010 yrosuso2009 yrosuso2008 yrosuso2007 ;
	do i=1 to dim(yrosuso);
		if yrosuso[i]=1 then rosuso_lastyoo=i+2006;
		if yrosusodec[i]=1 then rosuso_firstyoo=2015-i;
	end;

	rosuso_yearcount=rosuso_lastyoo-rosuso_firstyoo+1;

	* utilization variables;
	array util [*] rosuso_fillperiod_2007-rosuso_fillperiod_2014 rosuso_clms_2007 - rosuso_clms_2014
		rosuso_filldays_2007-rosuso_filldays_2014 rosuso_pdays_2007-rosuso_pdays_2014;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	rosuso_clms=sum(of rosuso_clms_2007-rosuso_clms_2014);
	rosuso_filldays=sum(of rosuso_filldays_2007-rosuso_filldays_2014);
	rosuso_pdays=sum(of rosuso_pdays_2007-rosuso_pdays_2014);

	* timing variables;
	rosuso_minfilldt=min(of rosuso_minfilldt_2007-rosuso_minfilldt_2014);
	rosuso_maxfilldt=max(of rosuso_maxfilldt_2007-rosuso_maxfilldt_2014);

	rosuso_fillperiod=rosuso_maxfilldt - rosuso_minfilldt+1;

	rosuso_pdayspy=rosuso_pdays/rosuso_yearcount;
	rosuso_filldayspy=rosuso_filldays/rosuso_yearcount;
	rosuso_clmspy=rosuso_clms/rosuso_yearcount;

	if first.bene_id; 
	
	drop i;
run;


* checks;
proc means data=statsaht.rosuso_0714p; run;











