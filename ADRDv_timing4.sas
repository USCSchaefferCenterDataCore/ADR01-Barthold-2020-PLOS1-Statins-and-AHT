/*********************************************************************************************/
title1 "ADRD Verification and Timing";

* Author: PF;
* Summary:
	•	Input: dementia_sum, bene_demad_samp_YYYY (08-13)
	•	Output: adrdv4_0813
	•	Take all the people with various ADRD diagnoses. Makes a file with their timing variables, for verified diagnoses. 
		Uses alzhe, alzhdmte, and incident_verify to make the variables within each year, then rowmin at end. AND does it all at end, so the file has both options. 
	•	Does all verification within years
	•	Effectively includes Patty’s old sample restrictions. ;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
libname ad "../../../data/dementiadx/";    
libname repbase "../../../data/aht/base";

/*********** Verification Flags ***********/

/*
incident_status: for the current year
   0="0.no AD or nonAD dementia"
   1="1.incident AD"
   2="2.incident nonAD dementia"
   3="3.incident AD-dementia before yr"   * this means the nonAD dementia DX was before current year, but first AD dx is in current year *
   4="4.incident nonAD dementia-AD before yr"   * this should never happen…if AD is the earliest dementia Dx then it will never be before a nonAD dx *
   7="7.already AD-dementia later"   * this should never happen either…same reasons as above *
   8="8.already nonAD dementia-AD later"  * this means dementia DX was prior to current year and AD dx came after current year *
   9="9.already AD and nonAD dementia"  * both AD/nonAD dx incident in a prior year *
   
incident_verify is:
	1 if the AD or non-AD dem is later confirmed as the same type
	2 if the AD or non-AD dem is later confirmed as any type of dementia (specified elsewhere)
	3 if the AD or non-AD dem is later switched to the other
	0 if we never see another dementia of any type
	.X if there's no incident (ie, nothing to be verified)
	//1 takes precedence over 2, which takes precendence over 3.
*/

%macro bene_ad(year);
data demad_samp_&year.;
	length alzhe alzhdmte 8.;
	set ad.bene_demad_samp_&year. (keep=bene_id incident_status incident_verify alzhe alzhdmte);
	if alzhdmte ne .;
	
	nadde=alzhdmte;
	if (alzhdmte=alzhe or alzhdmte>alzhe) and alzhdmte ne . and alzhe ne . then nadde=.;

	if year(alzhe)=&year. and (incident_verify=1 or incident_verify=2) then ADv_&year.=1;
	if ADv_&year.=1 then ADv_dt_&year.=alzhe;
	
	* adding verified ADRD;
	if year(alzhdmte)=&year. and (incident_verify=1 or incident_verify=2 or incident_verify=3) then ADRDv_&year.=1;
	if ADRDv_&year.=1 then ADRDv_dt_&year.=alzhdmte;
	
	rename incident_status=incident_status_&year. incident_verify=incident_verify_&year.;
	
run;

%mend;

%bene_ad(2008);
%bene_ad(2009);
%bene_ad(2010);
%bene_ad(2011);
%bene_ad(2012);
%bene_ad(2013);
%bene_ad(2014);
                  
/********** Merge **********/
data demad_samp_all;
	merge demad_samp_2008-demad_samp_2014;
	by bene_id;
run;

* Get birthday;
data birthday;
	set repbase.insamp_0714 (keep=bene_id bene_dob);
run;

data demad_samp_all1;
	merge demad_samp_all (in=a) birthday (in=b);
	by bene_id;
	if a;
run;
       
/********* Summary Variables *********/
* One obs per person, and everything xfilled from the merge;
* Note: ADv must be observed - meaning that they can only happen from 2008 on in this data
	AD, ADRD, and NADD all count events back to 1999;
	
data demad_samp_all2;
	set demad_samp_all1;
	
	* AD timing;
	AD_dt = alzhe;           
	AD_year = year(AD_dt);   
	AD_ageD = AD_dt-bene_dob;
  AD_age = AD_ageD/365;         
    
  ADv_dt = min(ADv_dt_2008, ADv_dt_2009, ADv_dt_2010, ADv_dt_2011, ADv_dt_2012, ADv_dt_2013, ADv_dt_2014);   
  ADv_year = year(ADv_dt);
  ADv_ageD = ADv_dt-bene_dob;                                                                  
  ADv_age = ADv_ageD/365;
  
  * ADRD timing;
  ADRD_dt = alzhdmte;          
  ADRD_year = year(ADRD_dt);   
  ADRD_ageD = ADRD_dt-bene_dob;
  ADRD_age = ADRD_ageD/365 ;
  
  ADRDv_dt = min(ADRDv_dt_2008, ADRDv_dt_2009, ADRDv_dt_2010, ADRDv_dt_2011, ADRDv_dt_2012, ADRDv_dt_2013, ADRDv_dt_2014);   
  ADRDv_year = year(ADRDv_dt);
  ADRDv_ageD = ADRDv_dt-bene_dob;                                                                  
  ADRDv_age = ADRDv_ageD/365;
  
  * Non AD dementia;
  NADD_dt = nadde;             
  NADD_year = year(NADD_dt);   
  NADD_ageD = NADD_dt-bene_dob;
  NADD_age = NADD_ageD/365;    
   
run;

* create perm;
data repbase.adrdv4_0814;
	set demad_samp_all2;
run;

* checks;
proc univariate data=demad_samp_all2; run;
                                                                     
                      
                                     


