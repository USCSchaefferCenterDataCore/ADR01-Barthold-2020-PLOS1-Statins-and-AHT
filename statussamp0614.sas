/*********************************************************************************************/
title1 'Drug Sample 2006-2013';

* Author: PF;
* Summary:
	•	Input: bene_status_yearYYYY.dta, bene_demog2013.dta
	•	Output: bene level: insamp_YYYY.dta, 0612 0812
	•	Gets status variables in each year, and requires insamp:
		o	3 full years of FFS enrollment, 3 full years in Part D. age_beg>=67. No drop flag.
	•	Makes vars for sex, race, and death date.;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i mprint merror;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
libname bene "&datalib.&clean_data.BeneStatus";
libname repbase "../../../data/aht/base";

/********* Sample **********/
* For 2004 & 2005, no part D data so doing out of the macro for the rest of the years;

* 2004;
data bene_status_2004; 
	set bene.bene_status_year2004 (keep=bene_id enrffs_allyr age_beg sex death_date birth_date); 
	if enrffs_allyr='Y' then ffs2004=1; else ffs2004=0;
	rename death_date=death_dt birth_date=bene_dob;
	drop enrffs_allyr age_beg;
run;

* 2005;
data bene_status_2005;
	set bene.bene_status_year2005 (keep=bene_id enrffs_allyr age_beg sex death_date birth_date); 
	if enrffs_allyr='Y' then ffs2005=1; else ffs2005=0;
	rename death_date=death_dt birth_date=bene_dob;
	drop enrffs_allyr age_beg;
run;

* Macro for accumulating merge;
%macro merge(yearm1,year);
	data bene_status_&year.;
		merge bene_status_&yearm1. bene_status_&year;
		by bene_id;
	run;
%mend;

%merge(2004,2005);

* Bringing in demog file;
data bene_demog;
	set bene.bene_demog2014;
	keep bene_id dropflag;
run;

* Macro for 2006-2013 ;
%macro sample(year,ffsyearm1,ffsyearm2,ptdyearm1,ptdyearm2,mergeyearm1);
	data bene_status_&year.;
		set bene.bene_status_year&year. (keep=bene_id enrffs_allyr ptd_allyr anyptd age_beg race_bg sex death_date birth_date);
		rename death_date=death_dt birth_date=bene_dob age_beg=age_beg_&year.;
		if enrffs_allyr='Y' then ffs&year.=1; else ffs&year.=0;
		if ptd_allyr='Y' then ptd&year.=1; else ptd&year.=0;
		drop enrffs_allyr ptd_allyr anyptd;
	run;
	
	%merge(&mergeyearm1.,&year.);

	data insamp_&year.;
		merge bene_status_&year. (in=a) bene_demog (in=b);
		by bene_id;
		if a and b;

		if (ffs&ffsyearm2.=1 and ffs&ffsyearm1.=1 and ffs&year.=1) and (ptd&ptdyearm2.=1 and ptd&ptdyearm1.=1 and ptd&year.=1)
		and age_beg_&year.>=67 and dropflag="N" then insamp_&year.=1;
		else insamp_&year.=0;
		
		if insamp_&year.;
		
		drop dropflag;
	run;
	
%mend;

* Input variables: 
			  year, 	ffsyear-1, ffsyear-2, ptdyear-1, ptdyear-2, mergeyear-1;
%sample(2006,		2005,			 2004,			2006,			 2006,			2005				);
%sample(2007,		2006,			 2005,		  2007,			 2007,			2006				); * in the original stata program, ptd 2006 not used;
%sample(2008,		2007,			 2006,		  2007,			 2007,			2007				); * in the original stata program, ptd 2006 not used again;
%sample(2009,		2008,			 2007,		  2008,			 2007,			2008				);
%sample(2010,		2009,			 2008,			2009,			 2008,			2009				);
%sample(2011,		2010,			 2009,			2010,			 2009,			2010				);
%sample(2012,		2011,		   2010,			2011,			 2010,			2011				);
%sample(2013,		2012,			 2011,			2012,			 2011,			2012				);
%sample(2014,		2013,			 2012,			2013,			 2012,			2013				)
						
/******** Merge 06-13 *********/
data insamp_0614;
	merge insamp_2006 (in=a) insamp_2007 (in=b) insamp_2008 (in=c) insamp_2009 (in=d) insamp_2010 (in=e) insamp_2011 (in=f) insamp_2012 (in=g) insamp_2013 (in=h) insamp_2014 (in=i);
	by bene_id;			
	array y [*] y2004-y2014;
	if a then do i=1 to 3;
		y[i]=1;
	end;
	if b then do i=2 to 4;
		y[i]=1;
	end;
	if c then do i=3 to 5;
		y[i]=1;
	end;
	if d then do i=4 to 6;
		y[i]=1;
	end;
	if e then do i=5 to 7;
		y[i]=1;
	end;
	if f then do i=6 to 8;
		y[i]=1;
	end;
	if g then do i=7 to 9;
		y[i]=1;
	end;
	if h then do i=8 to 10;
		y[i]=1;
	end;
	if i then do i=9 to 10;
		y[i]=1;
	end;
	drop i;
run;

/******** Make Vars *********/
data insamp_0614_1;
	set insamp_0614;
	by bene_id;
	
	* death timing;
	death_year=year(death_dt);
	death_ageD=death_dt-bene_dob;
	death_age=death_ageD/365;
	if death_dt ne . then dead=1;
	else dead=0;
	
	* years in samp;
	array dec [*] insamp_2014 insamp_2013 insamp_2012 insamp_2011 insamp_2010 insamp_2009 insamp_2008 insamp_2007 insamp_2006;
	array inc [*] insamp_2006 insamp_2007 insamp_2008 insamp_2009 insamp_2010 insamp_2011 insamp_2012 insamp_2013 insamp_2014;
	
	do i=1 to dim(inc);
		if dec[i]=1 then firstyis=2015-i;
		if inc[i]=1 then lastyis=2005+i;
	end;
	
	* years/days observed - check that these are the equivalent dates in stata;
	array y_dec [*] y2014 y2013 y2012 y2011 y2010 y2009 y2008 y2007 y2006;
	array y_inc [*] y2006 y2007 y2008 y2009 y2010 y2011 y2012 y2013 y2014; 
	do i=1 to dim(y_dec);
		if y_dec[i]=1 then firstyoo=2015-i;
		if y_inc[i]=1 then lastyoo=2005+i;
	end;
	
	firstdoo=mdy(1,1,firstyoo);
	
	lastdoo=mdy(12,31,lastyoo);
	
	if death_dt ne . and death_dt < lastdoo then do;
		lastdoo=death_dt;
		lastyoo=year(death_dt);
	end;
		
	format firstdoo lastdoo mmddyy10.;
	
	* race
		- 0 unknown
		- 1 white
		- 2 black
		- 3 other
		- 4 asian/pacific islander
		- 5 hispanic
		- 6 american indian/alaskan native;
	if race_bg="1" then race_dw=1; else race_dw=0;
	if race_bg="2" then race_db=1; else race_db=0;
	if race_bg="5" then race_dh=1; else race_dh=0;
	if race_bg in("0","3","4","6","") then race_do=1; else race_do=0;
		
	* sex 
		- 1 male
		- 2 female;
	if sex="2" then female=1; else female=0;
	
	drop i;
	
run;

/******** Merge Wide 07-13 ********/
data insamp_0714;
	merge insamp_2007 (in=b) insamp_2008 (in=c) insamp_2009 (in=d) insamp_2010 (in=e) insamp_2011 (in=f) insamp_2012 (in=g) insamp_2013 (in=h) insamp_2014 (in=i);
	by bene_id;			
	array y [*] y2005-y2014;
	if b then do i=1 to 3;
		y[i]=1;             
	end;                  
	if c then do i=2 to 4;
		y[i]=1;             
	end;                  
	if d then do i=3 to 5;
		y[i]=1;             
	end;                  
	if e then do i=4 to 6;
		y[i]=1;             
	end;                  
	if f then do i=5 to 7;
		y[i]=1;             
	end;                  
	if g then do i=6 to 8;
		y[i]=1;
	end;
	if h then do i=7 to 9;
		y[i]=1;
	end;
	if i then do i=8 to 10;
		y[i]=1;
	end;
	drop i;
run;

/********** Make Vars **********/
data insamp_0714_1;
	set insamp_0714;
	by bene_id;
	
	* death timing;
	death_year=year(death_dt);
	death_ageD=death_dt-bene_dob;
	death_age=death_ageD/365;
	if death_dt ne . then dead=1;
	else dead=0;
	
	* years in samp;
	array dec [*] insamp_2014 insamp_2013 insamp_2012 insamp_2011 insamp_2010 insamp_2009 insamp_2008 insamp_2007;
	array inc [*] insamp_2007 insamp_2008 insamp_2009 insamp_2010 insamp_2011 insamp_2012 insamp_2013 insamp_2014;
	
	do i=1 to dim(inc);
		if dec[i]=1 then firstyis=2015-i;
		if inc[i]=1 then lastyis=2006+i;
	end;
	
	* years/days observed - check that these are the equivalent dates in stata;
	array y_dec [*] y2014 y2013 y2012 y2011 y2010 y2009 y2008 y2007;
	array y_inc [*] y2007 y2008 y2009 y2010 y2011 y2012 y2013 y2014;
	do i=1 to dim(y_dec);
		if y_dec[i]=1 then firstyoo=2015-i;
		if y_inc[i]=1 then lastyoo=2006+i;
	end;
	
	firstdoo=mdy(1,1,firstyoo);
	
	lastdoo=mdy(12,31,lastyoo);
	
	if death_dt ne . and death_dt < lastdoo then do;
		lastdoo=death_dt;
		lastyoo=year(death_dt);
	end;
		
	format firstdoo lastdoo mmddyy10.;
	
	* race
		- 0 unknown
		- 1 white
		- 2 black
		- 3 other
		- 4 asian/pacific islander
		- 5 hispanic
		- 6 american indian/alaskan native;
	if race_bg="1" then race_dw=1; else race_dw=0;
	if race_bg="2" then race_db=1; else race_db=0;
	if race_bg="5" then race_dh=1; else race_dh=0;
	if race_bg in("0","3","4","6","") then race_do=1; else race_do=0;
		
	* sex 
		- 1 male
		- 2 female;
	if sex="2" then female=1; else female=0;
	
	drop i;
	
run;


* Create perms;

/*
data repbase.insamp_2006; set insamp_2006; run;
data repbase.insamp_2007; set insamp_2007; run;
data repbase.insamp_2008; set insamp_2008; run;
data repbase.insamp_2009; set insamp_2009; run;
data repbase.insamp_2010; set insamp_2010; run;
data repbase.insamp_2011; set insamp_2011; run;
data repbase.insamp_2012; set insamp_2012; run;
data repbase.insamp_2013; set insamp_2013; run;
*/
data repbase.insamp_2014; set insamp_2014; run;

data repbase.insamp_0614; set insamp_0614_1; run;
data repbase.insamp_0714; set insamp_0714_1; run;

* checks;
proc freq data=insamp_0614_1;
	table race_db race_dh race_do race_dw / missing;
run;

proc freq data=insamp_0714_1;
	table race_db race_dh race_do race_dw/ missing;
run;

proc contents data=insamp_0714_1; 
proc means data=insamp_0614_1;
proc means data=insamp_0714_1; run;



				
			