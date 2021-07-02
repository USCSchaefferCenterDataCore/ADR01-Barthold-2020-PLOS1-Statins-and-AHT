
clear all
set more off
capture log close

/*
•	Input: statinsaht_long0713.dta
•	Output: outreg
•	Sample: no prior ADccw. No deaths. Must have used a single class of AHT and statins in years t-1 and t-2. 
•	Outcomes: AD and ADccw
•	Treatment: 4 statins * 7 AHTs = 28 interactions
•	Full controls
*/

//Input the long file of Statins and AHT users
use "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/aht/statins+aht/statinsaht_long0714_902.dta", replace

//drop the obs for people after they get incident 
drop if ADccw_inc==2  

//drop the obs for people that died in that year
drop if death_year==year
drop if death_year<year

//keep only the obs in the long file where the person used a class of both in years t-1 and t-2
keep if (acei_user_L12==1 | a2rb_user_L12==1 | bblo_user_L12==1 | cchb_user_L12==1 | loop_user_L12==1 | thia_user_L12==1)
keep if (ator_user_L12==1 | pra_user_L12==1 | rosu_user_L12==1 | sim_user_L12==1)
keep if classcountstat_L12==1

//no one has NADD before the beginning of the year
//drop cmd_NADD

//drop hypertension variable
drop cmd_hyp
drop cmd_hyperl

//drop those that used an AChEI or memantine prior to reference year
drop if adrx_prior==1
count
codebook bene_id

//setup outreg
logistic ADv_inc ras_user_L1, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(SETUP 1) replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//																			  //
// 					LOGIT													  //
//																			  //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

///////////////  ADv 

//Just main terms
/*
logistic ADv_inc ator_user_L12 pra_user_L12 rosu_user_L12 sim_user_L12 acei_user_L12 a2rb_user_L12 age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
logistic ADv_inc ator_user_L12 pra_user_L12 rosu_user_L12 sim_user_L12 acei_user_L12 a2rb_user_L12 oth4_user_L12 age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
*/

//Just interactions
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12  ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, or vce(cluster county07)
	matrix logit1=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(1) modify
	putexcel A1="All", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit1),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12  ///
age agesq race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if female==1, or vce(cluster county07)
	matrix logit2=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(2) modify
	putexcel A1="Female", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit2),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12  ///
age agesq race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if female==0, or vce(cluster county07)
	matrix logit3=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(3) modify
	putexcel A1="Male", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit3),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, or vce(cluster county07)
	matrix logit4=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(4) modify
	putexcel A1="All - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit4),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if female==1, or vce(cluster county07)
	matrix logit5=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(5) modify
	putexcel A1="Female - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit5),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if female==0, or vce(cluster county07)
	matrix logit6=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(6) modify
	putexcel A1="Male - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit6),names left
	putexcel C3="OR"
	
// By Race
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dw==1, or vce(cluster county07)
	matrix logit7=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - White) modify
	putexcel A1="White", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit7),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_db==1, or vce(cluster county07)
	matrix logit8=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Black) modify
	putexcel A1="Black", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit8),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dh==1, or vce(cluster county07)
	matrix logit9=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Hispanic) modify
	putexcel A1="Hispanic", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit9),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_do==1, or vce(cluster county07)
	matrix logit10=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Other) modify
	putexcel A1="Other", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit10),names left
	putexcel C3="OR"
	
// By Race - Add Rosu
	logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12  ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dw==1, or vce(cluster county07)
	matrix logit11=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - White) modify
	putexcel A1="White - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit11),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_db==1, or vce(cluster county07)
	matrix logit12=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Black) modify
	putexcel A1="Black - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit12),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dh==1, or vce(cluster county07)
	matrix logit13=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Hispanic) modify
	putexcel A1="Hispanic - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit13),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq female i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_do==1, or vce(cluster county07)
	matrix logit14=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Other) modify
	putexcel A1="Other - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit14),names left
	putexcel C3="OR"
	
//Female, by Race 
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dw==1 & female==1, vce(cluster county07)
	matrix logit15=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Female White) modify
	putexcel A1="Female White", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit15),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_db==1 & female==1, vce(cluster county07)
	matrix logit16=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Female Black) modify
	putexcel A1="Female Black", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit16),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dh==1 & female==1, vce(cluster county07)
	matrix logit17=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Female Hispanic) modify
	putexcel A1="Female Hispanic", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit17),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_do==1 & female==1, vce(cluster county07)
	matrix logit18=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Female Other) modify
	putexcel A1="Female Other", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit18),names left
	putexcel C3="OR"
	
//Female, By Race-Add Rosu
	logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12  ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dw==1 & female==1, vce(cluster county07)
	matrix logit19=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Female White) modify
	putexcel A1="Female White - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit19),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_db==1 & female==1, vce(cluster county07)
	matrix logit20=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Female Black) modify
	putexcel A1="Female Black - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit20),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dh==1 & female==1, vce(cluster county07)
	matrix logit21=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Female Hispanic) modify
	putexcel A1="Female Hispanic - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit21),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_do==1 & female==1, vce(cluster county07)
	matrix logit22=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Female Other) modify
	putexcel A1="Female Other - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit22),names left
	putexcel C3="OR"
	
// By Race, Male
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dw==1 & female==0, vce(cluster county07)
	matrix logit23=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Male White) modify
	putexcel A1="Male White", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit23),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_db==1 & female==0, vce(cluster county07)
	matrix logit24=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Male Black) modify
	putexcel A1="Male Black", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit24),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dh==1 & female==0, vce(cluster county07)
	matrix logit25=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Male Hispanic) modify
	putexcel A1="Male Hispanic", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit25),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_do==1 & female==0, vce(cluster county07)
	matrix logit26=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Main - Male Other) modify
	putexcel A1="Male Other", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit26),names left
	putexcel C3="OR"
	
//By Race, Male - Add Rosu
	logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12  ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dw==1 & female==0, vce(cluster county07)
	matrix logit27=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Male White) modify
	putexcel A1="Male White - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit27),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_db==1 & female==0, vce(cluster county07)
	matrix logit28=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Male Black) modify
	putexcel A1="Male Black - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit28),names left
	putexcel C3="OR"
	
logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_dh==1 & female==0, vce(cluster county07)
	matrix logit29=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Male Hispanic) modify
	putexcel A1="Male Hispanic - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit29),names left
	putexcel C3="OR"

logit ADv_inc int_ator_acei_L12 int_sim_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_sim_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_rosu_oth4_L12 ///
age agesq  i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl if race_do==1 & female==0, vce(cluster county07)
	matrix logit30=r(table)'
	putexcel set "./output/AD_logit_ci.xlsx",sheet(Addl - Male Other) modify
	putexcel A1="Male Other - add rosu", bold
	putexcel B2="N="
	putexcel C2=(e(N)), nformat(number_sep)
	putexcel A3=matrix(logit30),names left
	putexcel C3="OR"

/*
logistic ADv_inc int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
logistic ADv_inc int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 int_sim_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_sim_a2rb_L12 ///
				int_ator_oth4_L12 int_pra_oth4_L12 int_rosu_oth4_L12 int_sim_oth4_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
logistic ADv_inc int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
				int_ator_oth4_L12 int_pra_oth4_L12 int_rosu_oth4_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append

//Main terms and interactions
/*
logistic ADv_inc ator_user_L12 pra_user_L12 rosu_user_L12 sim_user_L12 acei_user_L12 a2rb_user_L12 ///
				int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 int_sim_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_sim_a2rb_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
logistic ADv_inc ator_user_L12 pra_user_L12 rosu_user_L12 acei_user_L12 a2rb_user_L12 ///
				int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
logistic ADv_inc ator_user_L12 pra_user_L12 rosu_user_L12 sim_user_L12 acei_user_L12 a2rb_user_L12 oth4_user_L12 ///
				int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 int_sim_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 int_sim_a2rb_L12 ///
				int_ator_oth4_L12 int_pra_oth4_L12 int_rosu_oth4_L12 int_sim_oth4_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
logistic ADv_inc ator_user_L12 pra_user_L12 rosu_user_L12 acei_user_L12 a2rb_user_L12 oth4_user_L12 ///
				int_ator_acei_L12 int_pra_acei_L12 int_rosu_acei_L12 ///
				int_ator_a2rb_L12 int_pra_a2rb_L12 int_rosu_a2rb_L12 ///
				int_ator_oth4_L12 int_pra_oth4_L12 int_rosu_oth4_L12 ///
age agesq female race_d* i.hcc4_L1 cmd_* i.pct_hsgrads4_L1 i.medinc4_L1 i.phyvis4_L1 ys_hypert ys_hyperl, vce(cluster county07)
outreg2 using "./output/reg_saht1a3.xls", cttop(All) append
*/
