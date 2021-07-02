/*********************************************************************************************/
title1 'Geography Data';

* Author: PF;
* Summary:
	•	Input: bene_geo_YYYY.dta, 02-13. zcta2010tozip.dta. acs_educ_65up.dta, ACS_Income.dta
	•	Output: geoses_0613.dta, geoses_0713.dta, geoses_long0713.dta. geoses_0213.dta. geoses_long0213.dta
	•	Merges geo files, makes geographic control variables, and merges in education and income at the zip5 level.;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";

libname geo "&datalib.&clean_data.Geography/";
libname xwalk "&datalib.ContextData/Geography/Crosswalks/zip_to_2010ZCTA/MasterXwalk/";
libname acs "&datalib.ContextData/SAS/";
libname repbase "../../../data/aht/base";

/******* Bring in base data sets ******/

** Geo;
%macro geo;
%do year=2002 %to 2014;
data geo_&year.; set geo.bene_geo_&year. (keep=bene_id fips_state fips_county zip3 zip5); run;

proc sort data=geo_&year.; by bene_id; run;
%end;
%mend;

%geo;

** Zip code crosswalk;
data zcta;
	set xwalk.zcta2010tozip;
	rename zip=zip5;
	zcta5=fuzz(zcta5ce10*1);
	drop zcta5ce10;
run;

** Education;
data educ;
	set acs.acs_educ_65up (keep=zcta5 pct_hsgrads);
	if pct_hsgrads=. then delete;
run;

proc sort data=zcta; by zcta5; run;
proc sort data=educ; by zcta5; run;

data educ1;
	merge zcta (in=a) educ (in=b);
	by zcta5;
	if a and b;
run;

** Income;
data inc; 
	set acs.acs_income_raw (keep=zcta5 b19013_001e);
	rename b19013_001e=medinc;
	if b19013_001e=. then delete;
run;

proc sort data=inc; by zcta5; run;

data inc1;
	merge zcta (in=a) inc (in=b);
	by zcta5;
	if a and b;
run;

proc sort data=inc1; by zip5 year; run;

data inc2;
	set inc1;
	by zip5 year;
	if first.zip5;
	drop year;
run;

/********** Geography Wide 02-14 *********/
* Prioriziting early years;
data geo_wide_0214;
	merge geo_2014
				geo_2013
	      geo_2012
	      geo_2011
	      geo_2010
	      geo_2009
	      geo_2008
	      geo_2007
	      geo_2006
	      geo_2005
	      geo_2004
	      geo_2003
	      geo_2002;
	 by bene_id;
	 
	 * Census regions
	 		NE 1, MW 2, S 3, W 4, 0 5;
	 	if fips_state="01" then cen4=3; * AL;
	 	if fips_state="02" then cen4=4; * AK;
	 		* AS;
	 	if fips_state="04" then cen4=4; * AZ;
	 	if fips_state="05" then cen4=3; * AR;
	 	if fips_state="06" then cen4=4; * CA;
	 		* CZ;
	 	if fips_state="08" then cen4=4; * CO;
	 	if fips_state="09" then cen4=1; * CT;
	 	if fips_state="10" then cen4=3; * DE;
	 	if fips_state="11" then cen4=3; * DC;
	 	if fips_state="12" then cen4=3; * FL;
	 	if fips_state="13" then cen4=3; * GA;
	 		* GU;
	 	if fips_state="15" then cen4=4; * HI;
	 	if fips_state="16" then cen4=4; * ID;
	 	if fips_state="17" then cen4=2; * IL;
	 	if fips_state="18" then cen4=2; * IN;
	 	if fips_state="19" then cen4=2; * IA;
	 	if fips_state="20" then cen4=2; * KS;
		if fips_state="21" then cen4=3; * KY;   
		if fips_state="22" then cen4=3; * LA;   
		if fips_state="23" then cen4=1; * ME;   
		if fips_state="24" then cen4=3; * MD;   
		if fips_state="25" then cen4=1; * MA;   
		if fips_state="26" then cen4=2; * MI;   
		if fips_state="27" then cen4=2; * MN;   
		if fips_state="28" then cen4=3; * MS;   
		if fips_state="29" then cen4=2; * MO;   
		if fips_state="30" then cen4=4; * MT;   
		if fips_state="31" then cen4=2; * NE;   
		if fips_state="32" then cen4=4; * NV;   
		if fips_state="33" then cen4=1; * NH;   
		if fips_state="34" then cen4=1; * NJ;   
		if fips_state="35" then cen4=4; * NM;   
		if fips_state="36" then cen4=1; * NY;   
		if fips_state="37" then cen4=3; * NC;   
		if fips_state="38" then cen4=2; * ND;   
		if fips_state="39" then cen4=2; * OH;   
		if fips_state="40" then cen4=3; * OK;   
		if fips_state="41" then cen4=4; * OR;   
		if fips_state="42" then cen4=1; * PA;   
			* PR;             
		if fips_state="44" then cen4=1; * RI;   
		if fips_state="45" then cen4=3; * SC;    
		if fips_state="46" then cen4=2; * SD;   
		if fips_state="47" then cen4=3; * TN;   
		if fips_state="48" then cen4=3; * TX;   
		if fips_state="49" then cen4=4; * UT;    
		if fips_state="50" then cen4=1; * VT;   
		if fips_state="51" then cen4=3; * VA;   
			* VI;          
		if fips_state="53" then cen4=4; * WA;   
		if fips_state="54" then cen4=3; * WV;    
		if fips_state="55" then cen4=2; * WI;    
		if fips_state="56" then cen4=4; * WY;    
		if fips_state="60" then cen4=5; * AS;    
		if fips_state="66" then cen4=5; * GU;    
		if fips_state="72" then cen4=5; * PR;    
		if fips_state="78" then cen4=5; * VI;    
		if fips_state="FC" then cen4=5; * UP, FC;

run;

* Add education;
	* Prioritize 2002 value but otherwise take earliest;
data educ_0214;
	set educ1;
	if year=2002 then pct_hsg=pct_hsgrads;
run;

proc freq data=educ_0214 noprint;
	where pct_hsg ne .;
	table zip5*pct_hsg / out=zip_pct_hsg02 (drop=count percent);
run;

proc sort data=educ_0214; by zip5 year; run;

data educ_0214_1;
	merge educ_0214 (in=a) zip_pct_hsg02 (in=b);
	by zip5;
	if pct_hsg=. then pct_hsg=pct_hsgrads; * Filling in for those that don't merge to zip;
	if first.zip5; * Keeping earliest;
run;

proc sort data=geo_wide_0214; by zip5; run;

* Merge Education and Income to Geo Wide;
data geo_wide_0214_1;
	merge geo_wide_0214 (in=a) educ_0214_1 (in=b rename=zcta5=educ_zcta5) inc2 (in=c);
	by zip5;
	if a;	
	if zcta5=. then zcta5=educ_zcta5;	
	keep bene_id fips_state fips_county zip3 zip5 cen4 zcta5 pct_hsg medinc;
run;

* create perm;
data repbase.geoses_0214;
	set geo_wide_0214_1;
run;

/******** Geography Wide 06-14 *******/
* Prioriziting early years;
data geo_wide_0614;
	merge geo_2014
				geo_2013
	      geo_2012
	      geo_2011
	      geo_2010
	      geo_2009
	      geo_2008
	      geo_2007
	      geo_2006;
	 by bene_id;
	 
	 * Census regions
	 		NE 1, MW 2, S 3, W 4, 0 5;
	 	if fips_state="01" then cen4=3; * AL;
	 	if fips_state="02" then cen4=4; * AK;
	 		* AS;
	 	if fips_state="04" then cen4=4; * AZ;
	 	if fips_state="05" then cen4=3; * AR;
	 	if fips_state="06" then cen4=4; * CA;
	 		* CZ;
	 	if fips_state="08" then cen4=4; * CO;
	 	if fips_state="09" then cen4=1; * CT;
	 	if fips_state="10" then cen4=3; * DE;
	 	if fips_state="11" then cen4=3; * DC;
	 	if fips_state="12" then cen4=3; * FL;
	 	if fips_state="13" then cen4=3; * GA;
	 		* GU;
	 	if fips_state="15" then cen4=4; * HI;
	 	if fips_state="16" then cen4=4; * ID;
	 	if fips_state="17" then cen4=2; * IL;
	 	if fips_state="18" then cen4=2; * IN;
	 	if fips_state="19" then cen4=2; * IA;
	 	if fips_state="20" then cen4=2; * KS;
		if fips_state="21" then cen4=3; * KY;   
		if fips_state="22" then cen4=3; * LA;   
		if fips_state="23" then cen4=1; * ME;   
		if fips_state="24" then cen4=3; * MD;   
		if fips_state="25" then cen4=1; * MA;   
		if fips_state="26" then cen4=2; * MI;   
		if fips_state="27" then cen4=2; * MN;   
		if fips_state="28" then cen4=3; * MS;   
		if fips_state="29" then cen4=2; * MO;   
		if fips_state="30" then cen4=4; * MT;   
		if fips_state="31" then cen4=2; * NE;   
		if fips_state="32" then cen4=4; * NV;   
		if fips_state="33" then cen4=1; * NH;   
		if fips_state="34" then cen4=1; * NJ;   
		if fips_state="35" then cen4=4; * NM;   
		if fips_state="36" then cen4=1; * NY;   
		if fips_state="37" then cen4=3; * NC;   
		if fips_state="38" then cen4=2; * ND;   
		if fips_state="39" then cen4=2; * OH;   
		if fips_state="40" then cen4=3; * OK;   
		if fips_state="41" then cen4=4; * OR;   
		if fips_state="42" then cen4=1; * PA;   
			* PR;             
		if fips_state="44" then cen4=1; * RI;   
		if fips_state="45" then cen4=3; * SC;    
		if fips_state="46" then cen4=2; * SD;   
		if fips_state="47" then cen4=3; * TN;   
		if fips_state="48" then cen4=3; * TX;   
		if fips_state="49" then cen4=4; * UT;    
		if fips_state="50" then cen4=1; * VT;   
		if fips_state="51" then cen4=3; * VA;   
			* VI;          
		if fips_state="53" then cen4=4; * WA;   
		if fips_state="54" then cen4=3; * WV;    
		if fips_state="55" then cen4=2; * WI;    
		if fips_state="56" then cen4=4; * WY;    
		if fips_state="60" then cen4=5; * AS;    
		if fips_state="66" then cen4=5; * GU;    
		if fips_state="72" then cen4=5; * PR;    
		if fips_state="78" then cen4=5; * VI;    
		if fips_state="FC" then cen4=5; * UP, FC;

run;

* Add education;
	* Prioritize 2006 value but otherwise take earliest;
data educ_0614;
	set educ1;
	if year=2006 then pct_hsg=pct_hsgrads;
run;

proc freq data=educ_0614 noprint;
	where pct_hsg ne .;
	table zip5*pct_hsg / out=zip_pct_hsg06 (drop=count percent);
run;

proc sort data=educ_0614; by zip5 year; run;

data educ_0614_1;
	merge educ_0614 (in=a) zip_pct_hsg06 (in=b);
	by zip5;
	if pct_hsg=. then pct_hsg=pct_hsgrads; * Filling in for those that don't merge to zip;
	if first.zip5; * Keeping earliest;
run;

proc sort data=geo_wide_0614; by zip5; run;

* Merge Education and Income to Geo Wide;
data geo_wide_0614_1;
	merge geo_wide_0614 (in=a) educ_0614_1 (in=b rename=zcta5=educ_zcta5) inc2 (in=c);
	by zip5;
	if a;
	if zcta5=. then zcta5=educ_zcta5;
	keep bene_id fips_state fips_county zip3 zip5 cen4 zcta5 pct_hsg medinc;
run;

* create perm;
data repbase.geoses_0614;
	set geo_wide_0614_1;
run;


/******** Geography Wide 07-14 *******/
* Prioriziting early years;
data geo_wide_0714;
	merge geo_2014
				geo_2013
	      geo_2012
	      geo_2011
	      geo_2010
	      geo_2009
	      geo_2008
	      geo_2007;
	 by bene_id;
	 
	 * Census regions
	 		NE 1, MW 2, S 3, W 4, 0 5;
	 	if fips_state="01" then cen4=3; * AL;
	 	if fips_state="02" then cen4=4; * AK;
	 		* AS;
	 	if fips_state="04" then cen4=4; * AZ;
	 	if fips_state="05" then cen4=3; * AR;
	 	if fips_state="06" then cen4=4; * CA;
	 		* CZ;
	 	if fips_state="08" then cen4=4; * CO;
	 	if fips_state="09" then cen4=1; * CT;
	 	if fips_state="10" then cen4=3; * DE;
	 	if fips_state="11" then cen4=3; * DC;
	 	if fips_state="12" then cen4=3; * FL;
	 	if fips_state="13" then cen4=3; * GA;
	 		* GU;
	 	if fips_state="15" then cen4=4; * HI;
	 	if fips_state="16" then cen4=4; * ID;
	 	if fips_state="17" then cen4=2; * IL;
	 	if fips_state="18" then cen4=2; * IN;
	 	if fips_state="19" then cen4=2; * IA;
	 	if fips_state="20" then cen4=2; * KS;
		if fips_state="21" then cen4=3; * KY;   
		if fips_state="22" then cen4=3; * LA;   
		if fips_state="23" then cen4=1; * ME;   
		if fips_state="24" then cen4=3; * MD;   
		if fips_state="25" then cen4=1; * MA;   
		if fips_state="26" then cen4=2; * MI;   
		if fips_state="27" then cen4=2; * MN;   
		if fips_state="28" then cen4=3; * MS;   
		if fips_state="29" then cen4=2; * MO;   
		if fips_state="30" then cen4=4; * MT;   
		if fips_state="31" then cen4=2; * NE;   
		if fips_state="32" then cen4=4; * NV;   
		if fips_state="33" then cen4=1; * NH;   
		if fips_state="34" then cen4=1; * NJ;   
		if fips_state="35" then cen4=4; * NM;   
		if fips_state="36" then cen4=1; * NY;   
		if fips_state="37" then cen4=3; * NC;   
		if fips_state="38" then cen4=2; * ND;   
		if fips_state="39" then cen4=2; * OH;   
		if fips_state="40" then cen4=3; * OK;   
		if fips_state="41" then cen4=4; * OR;   
		if fips_state="42" then cen4=1; * PA;   
			* PR;             
		if fips_state="44" then cen4=1; * RI;   
		if fips_state="45" then cen4=3; * SC;    
		if fips_state="46" then cen4=2; * SD;   
		if fips_state="47" then cen4=3; * TN;   
		if fips_state="48" then cen4=3; * TX;   
		if fips_state="49" then cen4=4; * UT;    
		if fips_state="50" then cen4=1; * VT;   
		if fips_state="51" then cen4=3; * VA;   
			* VI;          
		if fips_state="53" then cen4=4; * WA;   
		if fips_state="54" then cen4=3; * WV;    
		if fips_state="55" then cen4=2; * WI;    
		if fips_state="56" then cen4=4; * WY;    
		if fips_state="60" then cen4=5; * AS;    
		if fips_state="66" then cen4=5; * GU;    
		if fips_state="72" then cen4=5; * PR;    
		if fips_state="78" then cen4=5; * VI;    
		if fips_state="FC" then cen4=5; * UP, FC;

run;

proc sort data=geo_wide_0714; by zip5; run;

* Prioritize 2007 value, but otherwise take earliest;
data educ_0714;
	set educ1;
	if year=2007 then pct_hsg=pct_hsgrads;
run;

proc freq data=educ_0714 noprint;
	where pct_hsg ne .;
	table zip5*pct_hsg / out=zip_pct_hsg07 (drop=count percent);
run;

proc sort data=educ_0714; by zip5 year; run;

data educ_0714_1;
	merge educ_0714 (in=a) zip_pct_hsg07 (in=b);
	by zip5;
	if pct_hsg=. then pct_hsg=pct_hsgrads; * Filling in for those that don't merge to zip;
	if first.zip5; * Keeping earliest;
run;

* Merge Education and Income to Geo Wide;
data geo_wide_0714_1;
	merge geo_wide_0714 (in=a) educ_0714_1 (in=b rename=zcta5=educ_zcta5) inc2 (in=c);
	by zip5;
	if a;
	if zcta5=. then zcta5=educ_zcta5;
	keep bene_id fips_state fips_county zip3 zip5 cen4 zcta5 pct_hsg medinc;
run;

* create perm;
data repbase.geoses_0714;
	set geo_wide_0714_1;
run;

/******** Geography Long 07-14 *******/
data geo_long_0714;
	set geo_2007 (in=a)
	    geo_2008 (in=b)
	    geo_2009 (in=c)
	    geo_2010 (in=d)
	    geo_2011 (in=e)
	    geo_2012 (in=f)
	    geo_2013 (in=g)
	    geo_2014 (in=h);
	if a then year=2007;
	if b then year=2008;
	if c then year=2009;
	if d then year=2010;
	if e then year=2011;
	if f then year=2012;
	if g then year=2013;
	if h then year=2014;
	
  * Census regions
	 		NE 1, MW 2, S 3, W 4, 0 5;
	 	if fips_state="01" then cen4=3; * AL;
	 	if fips_state="02" then cen4=4; * AK;
	 		* AS;
	 	if fips_state="04" then cen4=4; * AZ;
	 	if fips_state="05" then cen4=3; * AR;
	 	if fips_state="06" then cen4=4; * CA;
	 		* CZ;
	 	if fips_state="08" then cen4=4; * CO;
	 	if fips_state="09" then cen4=1; * CT;
	 	if fips_state="10" then cen4=3; * DE;
	 	if fips_state="11" then cen4=3; * DC;
	 	if fips_state="12" then cen4=3; * FL;
	 	if fips_state="13" then cen4=3; * GA;
	 		* GU;
	 	if fips_state="15" then cen4=4; * HI;
	 	if fips_state="16" then cen4=4; * ID;
	 	if fips_state="17" then cen4=2; * IL;
	 	if fips_state="18" then cen4=2; * IN;
	 	if fips_state="19" then cen4=2; * IA;
	 	if fips_state="20" then cen4=2; * KS;
		if fips_state="21" then cen4=3; * KY;   
		if fips_state="22" then cen4=3; * LA;   
		if fips_state="23" then cen4=1; * ME;   
		if fips_state="24" then cen4=3; * MD;   
		if fips_state="25" then cen4=1; * MA;   
		if fips_state="26" then cen4=2; * MI;   
		if fips_state="27" then cen4=2; * MN;   
		if fips_state="28" then cen4=3; * MS;   
		if fips_state="29" then cen4=2; * MO;   
		if fips_state="30" then cen4=4; * MT;   
		if fips_state="31" then cen4=2; * NE;   
		if fips_state="32" then cen4=4; * NV;   
		if fips_state="33" then cen4=1; * NH;   
		if fips_state="34" then cen4=1; * NJ;   
		if fips_state="35" then cen4=4; * NM;   
		if fips_state="36" then cen4=1; * NY;   
		if fips_state="37" then cen4=3; * NC;   
		if fips_state="38" then cen4=2; * ND;   
		if fips_state="39" then cen4=2; * OH;   
		if fips_state="40" then cen4=3; * OK;   
		if fips_state="41" then cen4=4; * OR;   
		if fips_state="42" then cen4=1; * PA;   
			* PR;             
		if fips_state="44" then cen4=1; * RI;   
		if fips_state="45" then cen4=3; * SC;    
		if fips_state="46" then cen4=2; * SD;   
		if fips_state="47" then cen4=3; * TN;   
		if fips_state="48" then cen4=3; * TX;   
		if fips_state="49" then cen4=4; * UT;    
		if fips_state="50" then cen4=1; * VT;   
		if fips_state="51" then cen4=3; * VA;   
			* VI;          
		if fips_state="53" then cen4=4; * WA;   
		if fips_state="54" then cen4=3; * WV;    
		if fips_state="55" then cen4=2; * WI;    
		if fips_state="56" then cen4=4; * WY;    
		if fips_state="60" then cen4=5; * AS;    
		if fips_state="66" then cen4=5; * GU;    
		if fips_state="72" then cen4=5; * PR;    
		if fips_state="78" then cen4=5; * VI;    
		if fips_state="FC" then cen4=5; * UP, FC;
			
run;

* Add education;
proc sort data=educ1; by zip5 year; run;

data educ_long;
	set educ1;
	by zip5 year;
	if first.zip5;
	drop year;
run;

proc sort data=geo_long_0714; by zip5; run;

* Merge education and income to long;
data geo_long_0714_1;
	merge geo_long_0714 (in=a) educ_long (in=b rename=zcta5=educ_zcta5) inc2 (in=c);
	by zip5;
	if a;
	if zcta5=. then zcta5=educ_zcta5;
	keep bene_id year fips_state fips_county zip3 zip5 cen4 zcta5 pct_hsgrads medinc;
run;

* create perm;
data repbase.geoses_long0714;
	set geo_long_0714_1;
run;

/********* Geography Long 02-14 *********/
 data geo_long_0214;
	set geo_2002 (in=h)
	    geo_2003 (in=i)
			geo_2004 (in=j)
			geo_2005 (in=k)
			geo_2006 (in=l)
			geo_2007 (in=a)
	    geo_2008 (in=b)
	    geo_2009 (in=c)
	    geo_2010 (in=d)
	    geo_2011 (in=e)
	    geo_2012 (in=f)
	    geo_2013 (in=g)
	    geo_2014 (in=h);
	if h then year=2002;
	if i then year=2003;
	if j then year=2004;
	if k then year=2005;
	if l then year=2006;  
	if a then year=2007;
	if b then year=2008;
	if c then year=2009;
	if d then year=2010;
	if e then year=2011;
	if f then year=2012;
	if g then year=2013;
	if h then year=2014;
	
  * Census regions
	 		NE 1, MW 2, S 3, W 4, 0 5;
	 	if fips_state="01" then cen4=3; * AL;
	 	if fips_state="02" then cen4=4; * AK;
	 		* AS;
	 	if fips_state="04" then cen4=4; * AZ;
	 	if fips_state="05" then cen4=3; * AR;
	 	if fips_state="06" then cen4=4; * CA;
	 		* CZ;
	 	if fips_state="08" then cen4=4; * CO;
	 	if fips_state="09" then cen4=1; * CT;
	 	if fips_state="10" then cen4=3; * DE;
	 	if fips_state="11" then cen4=3; * DC;
	 	if fips_state="12" then cen4=3; * FL;
	 	if fips_state="13" then cen4=3; * GA;
	 		* GU;
	 	if fips_state="15" then cen4=4; * HI;
	 	if fips_state="16" then cen4=4; * ID;
	 	if fips_state="17" then cen4=2; * IL;
	 	if fips_state="18" then cen4=2; * IN;
	 	if fips_state="19" then cen4=2; * IA;
	 	if fips_state="20" then cen4=2; * KS;
		if fips_state="21" then cen4=3; * KY;   
		if fips_state="22" then cen4=3; * LA;   
		if fips_state="23" then cen4=1; * ME;   
		if fips_state="24" then cen4=3; * MD;   
		if fips_state="25" then cen4=1; * MA;   
		if fips_state="26" then cen4=2; * MI;   
		if fips_state="27" then cen4=2; * MN;   
		if fips_state="28" then cen4=3; * MS;   
		if fips_state="29" then cen4=2; * MO;   
		if fips_state="30" then cen4=4; * MT;   
		if fips_state="31" then cen4=2; * NE;   
		if fips_state="32" then cen4=4; * NV;   
		if fips_state="33" then cen4=1; * NH;   
		if fips_state="34" then cen4=1; * NJ;   
		if fips_state="35" then cen4=4; * NM;   
		if fips_state="36" then cen4=1; * NY;   
		if fips_state="37" then cen4=3; * NC;   
		if fips_state="38" then cen4=2; * ND;   
		if fips_state="39" then cen4=2; * OH;   
		if fips_state="40" then cen4=3; * OK;   
		if fips_state="41" then cen4=4; * OR;   
		if fips_state="42" then cen4=1; * PA;   
			* PR;             
		if fips_state="44" then cen4=1; * RI;   
		if fips_state="45" then cen4=3; * SC;    
		if fips_state="46" then cen4=2; * SD;   
		if fips_state="47" then cen4=3; * TN;   
		if fips_state="48" then cen4=3; * TX;   
		if fips_state="49" then cen4=4; * UT;    
		if fips_state="50" then cen4=1; * VT;   
		if fips_state="51" then cen4=3; * VA;   
			* VI;          
		if fips_state="53" then cen4=4; * WA;   
		if fips_state="54" then cen4=3; * WV;    
		if fips_state="55" then cen4=2; * WI;    
		if fips_state="56" then cen4=4; * WY;    
		if fips_state="60" then cen4=5; * AS;    
		if fips_state="66" then cen4=5; * GU;    
		if fips_state="72" then cen4=5; * PR;    
		if fips_state="78" then cen4=5; * VI;    
		if fips_state="FC" then cen4=5; * UP, FC;
			
run;

proc sort data=geo_long_0214; by zip5; run;

* Merge education and income to long;
data geo_long_0214_1;
	merge geo_long_0214 (in=a) educ_long (in=b rename=zcta5=educ_zcta5) inc2 (in=c);
	by zip5;
	if a;
	if zcta5=. then zcta5=educ_zcta5;
	keep bene_id year fips_state fips_county zip3 zip5 cen4 zcta5 pct_hsgrads medinc;
run;

* create perm;
data repbase.geoses_long0214;
	set geo_long_0214_1;
run;

* checks;
proc univariate data=geo_wide_0214_1; run;
proc univariate data=geo_wide_0614_1; run;
proc univariate data=geo_wide_0714_1; run;
proc univariate data=geo_long_0714_1; run;
proc univariate data=geo_long_0214_1; run;
