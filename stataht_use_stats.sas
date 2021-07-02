/*********************************************************************************************/
title1 "Analytical AHT Data - 90 Days, 2 Claims";

* Summary:
•	Input: ahtco_long0713a.dta, adrdv4_0813.dta, hcc_long0713.dta, ccw_0713.dta, geoedu_long0713.dta, stat_long0713.dta, phy_long0613.dta, adrx_long0713.dta
•	Output: ahtco_long0713_902.dta
	o	Note that this file includes observations for people after they get ADRD (or whatever).
	o	It also includes obs for people in the year that they die. 
	o	Includes all the people who got AD 1999-2007 (not picked up in the ADv variable)
	o	In subsequent files, you need to drop the observations that occur after the diagnosis of interest. Maybe also drop dying people. 
•	In the long file of aht use, merges in concurrent obs for AD diagnoses, HCC, CCW, geoedu, and statin use. 
•	Makes RAS vars, user vars, combo vars and lags of those for the 14 classes, and statins. 
•	Makes AD_inc vars, comorbidity variables.;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error dkrocond=error msglevel=i mprint;
/*********************************************************************************************/

%include "../../../../../../51866/PROGRAMS/setup.inc";

libname base "../../../../data/aht/base/";
libname poly "../../../../data/aht/poly/";
libname ad "../../../../data/aht/addrug/";
libname aht "../../../../data/aht/statins+aht/";

proc contents data=aht.statinsaht_long0714_902; run;
	
proc print data=aht.statinsaht_long0714_902 (obs=100);
	var bene_id year insamp: aht_user ras_user acei_user a2rb_user
	bblo_user cchb_user loop_user thia_user oth4_user 
	ator_user pra_user rosu_user sim_user;
run;

proc print data=aht.statinsaht_long0714_902 (obs=100);
	var bene_id year insamp: aht_user ras_user acei_user a2rb_user
	bblo_user cchb_user loop_user thia_user oth4_user 
	ator_user pra_user rosu_user sim_user;
	where bene_id in('mmmmmmDXaDDGJJJ','mmmmmmDXaDDGsDW');
run;

proc print data=aht.statinsaht_long0714_902 (obs=100);
	var bene_id year insamp: aht_user ras_user acei_user a2rb_user
	bblo_user cchb_user loop_user thia_user oth4_user 
	ator_user pra_user rosu_user sim_user;
	where max(aht_user,ras_user,acei_user,a2rb_user,
	bblo_user,cchb_user,loop_user,thia_user,oth4_user,
	ator_user,pra_user,rosu_user,sim_user)=0;
run;

* Table/Figure of prevalence rates of use;
proc means data=aht.statinsaht_long0714_902 noprint nway;
	class year;
	output out=prev_byyear mean(aht_user ras_user acei_user a2rb_user oth4_user
	ator_user pra_user rosu_user sim_user)=;
run;

proc freq data=aht.statinsaht_long0714_902 noprint;
	where ras_user=0;
	table year / out=prev_nonras_byyear;
run;

ods excel file="./output/prev_byyear.xlsx";
proc print data=prev_byyear; run;
proc print data=prev_nonras_byyear; run;
ods excel close;