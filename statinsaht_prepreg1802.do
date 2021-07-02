clear all
set more off
capture log close
log using statinsaht_prepreg1802.log, replace text

/*
•	Input: ahtco_long0713a.dta, statins_long0713a.dta
o	adrdv4_0813.dta, hcc_long0713.dta, ccw_0713.dta, geoedu_long0713.dta, stat_long0713.dta, phy_long0613.dta, adrx_long0713.dta
•	Output: statinsaht_long0713.dta
o	Note that this file includes observations for people after they get ADRD (or whatever).
o	It also includes obs for people in the year that they die. 
o	Includes all the people who got AD 1999-2007 (not picked up in the ADv variable)
o	In subsequent files, you need to drop the observations that occur after the diagnosis of interest. Maybe also drop dying people. 
•	In the long file of statins and aht use, merges in concurrent obs for AD diagnoses, HCC, CCW, geoses.
•	Makes RAS vars, user vars, combo vars and lags of those for statins and ahts. 
•	Makes AD_inc vars, comorbidity variables.
*/

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//																			  //
//			Make t and t-1 variables for drug use, diagnoses, 				  //
//																			  //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
use "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/aht/statins+aht/statinsaht_long0714b.dta", replace

sort bene_id year
////////////////////////////////////////////////////////////////////////////////
///////////////////////    	AHT VARIABLES       	////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//Make summary variables for acei a2rb bblo cchb loop thia, ras
/* 10 subgroups:
	aceiso aceicchb aceithia 
	a2rbso a2rbthia 
	bbloso bblothia 
	cchbso  
	loopso
	thiaso

	plus the atorcchb
*/

//Aggregate categories variables
//Make clm, pday, and user vars for the aggregate categories
//Each of these (acei a2rb bblo cchb loop thia ras aht) all include the use of the corresponding combo pills
gen acei_clms = 0
gen acei_pdays = 0
replace acei_clms = aceiso_clms + aceicchb_clms + aceithia_clms
replace acei_pdays = aceiso_pdays + aceicchb_pdays + aceithia_pdays
replace acei_pdays = 365 if acei_pdays>365

gen a2rb_clms = 0
gen a2rb_pdays = 0
replace a2rb_clms = a2rbso_clms + a2rbthia_clms 
replace a2rb_pdays = a2rbso_pdays + a2rbthia_pdays 
replace a2rb_pdays = 365 if a2rb_pdays>365

gen bblo_clms = 0
gen bblo_pdays = 0
replace bblo_clms = bbloso_clms + bblothia_clms
replace bblo_pdays = bbloso_pdays + bblothia_pdays
replace bblo_pdays = 365 if bblo_pdays>365

gen cchb_clms = 0
gen cchb_pdays = 0
replace cchb_clms = cchbso_clms + aceicchb_clms + atorcchb_clms
replace cchb_pdays = cchbso_pdays + aceicchb_pdays + atorcchb_pdays
replace cchb_pdays = 365 if cchb_pdays>365

gen loop_clms = 0
gen loop_pdays = 0
replace loop_clms = loopso_clms 
replace loop_pdays = loopso_pdays 
replace loop_pdays = 365 if loop_pdays>365

gen thia_clms = 0
gen thia_pdays = 0
replace thia_clms = thiaso_clms + aceithia_clms + a2rbthia_clms + bblothia_clms
replace thia_pdays = thiaso_pdays + aceithia_pdays + a2rbthia_pdays + bblothia_pdays
replace thia_pdays = 365 if thia_pdays>365

gen aht_clms = 0
gen aht_pdays = 0
replace aht_clms = acei_clms + a2rb_clms + bblo_clms + cchb_clms + loop_clms + thia_clms
replace aht_pdays = acei_pdays + a2rb_pdays + bblo_pdays + cchb_pdays + loop_pdays + thia_pdays
replace aht_pdays = 365 if aht_pdays>365

gen ras_clms = 0
gen ras_pdays = 0
replace ras_clms = acei_clms + a2rb_clms
replace ras_pdays = acei_pdays + a2rb_pdays
replace ras_pdays = 365 if ras_pdays>365

gen rasso_clms = 0
gen rasso_pdays = 0
replace rasso_clms = aceiso_clms + a2rbso_clms
replace rasso_pdays = aceiso_pdays + a2rbso_pdays
replace rasso_pdays = 365 if rasso_pdays>365

//user vars
// note: user vars in the bigger categories pick up people that fall into none of the sub-categories. 
local vars1 "aht ras rasso acei aceiso aceicchb aceithia a2rb a2rbso a2rbthia bblo bbloso bblothia cchb cchbso loop loopso thia thiaso"
local vars "aht ras acei a2rb bblo cchb loop thia adrx"
foreach i in `vars'{
	gen `i'_user = 0
	replace `i'_user = 1 if `i'_pdays>=180 & `i'_clms>=2
}

//lag vars
foreach i in `vars'{
	gen `i'_user_L1 = 0
	replace `i'_user_L1 = 1 if `i'_pdays[_n-1]>=180 & `i'_clms[_n-1]>=2 & bene_id==bene_id[_n-1]
	replace `i'_user_L1 = . if year==2007
	
	gen `i'_user_L12 = 0
	replace `i'_user_L12 = 1 if `i'_pdays[_n-1]>=180 & `i'_pdays[_n-2]>=180 & `i'_clms[_n-1]>=2 & `i'_clms[_n-2]>=2 & bene_id==bene_id[_n-1] & bene_id==bene_id[_n-2]
	replace `i'_user_L12 = . if year==2007 | year==2008  

	gen `i'_user_L2 = 0
	replace `i'_user_L2 = 1 if `i'_pdays[_n-2]>=180 & `i'_clms[_n-2]>=2 & bene_id==bene_id[_n-2]
	replace `i'_user_L2 = . if year==2007 | year==2008  
}

////////////	Current
gen classcount = 0
replace classcount = acei_user + a2rb_user + bblo_user + cchb_user + loop_user + thia_user

gen any_solo = 0
replace any_solo = 1 if classcount==1

gen any_combo = 0
replace any_combo = 1 if classcount>1 & classcount!=.

////////////	L1
gen classcount_L1 = 0
replace classcount_L1 = acei_user_L1 + a2rb_user_L1 + bblo_user_L1 + cchb_user_L1 + loop_user_L1 + thia_user_L1

gen any_solo_L1 = 0
replace any_solo_L1 = 1 if classcount_L1==1

gen any_combo_L1 = 0
replace any_combo_L1 = 1 if classcount_L1>1 & classcount_L1!=.

//L2
gen classcount_L2 = 0
replace classcount_L2 = acei_user_L2 + a2rb_user_L2 + bblo_user_L2 + cchb_user_L2 + loop_user_L2 + thia_user_L2

////////////	L12
gen classcount_L12 = 0
replace classcount_L12 = acei_user_L12 + a2rb_user_L12 + bblo_user_L12 + cchb_user_L12 + loop_user_L12 + thia_user_L12

gen any_solo_L12 = 0
replace any_solo_L12 = 1 if classcount_L12==1 & classcount_L1==1 & classcount_L2==1

gen any_combo_L12 = 0
replace any_combo_L12 = 1 if classcount_L12>1 & classcount_L12!=.

//////////////  Other 4
//any of the other 4
gen oth4_user = 0
replace oth4_user = 1 if bblo_user==1 | cchb_user==1 | loop_user==1 | thia_user==1
gen oth4_user_L12 = 0
replace oth4_user_L12 = 1 if bblo_user_L12==1 | cchb_user_L12==1 | loop_user_L12==1 | thia_user_L12==1

//1 RAS at the the threshold
gen ras1_user = 0
replace ras1_user = 1 if acei_user==1 | a2rb_user==1
gen ras1_user_L12 = 0
replace ras1_user_L12 = 1 if acei_user_L12==1 | a2rb_user_L12==1

////////////////////////////////////////////////////////////////////////////////
///////////////////////    	STATINS VARIABLES       ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//Make summary variables for ator pra rosu sim
/* 5 subgroups:
	atorso
	atorcchb
	praso
	rosuso
	simso
*/

//Aggregate categories variables
//Make clm, pday, and user vars for the aggregate categories
//Each of these (ator pra rosu sim stat) all include the use of the corresponding combo pills
gen ator_clms = 0
gen ator_pdays = 0
replace ator_clms = atorso_clms + atorcchb_clms
replace ator_pdays = atorso_pdays + atorcchb_pdays
replace ator_pdays = 365 if ator_pdays>365

gen pra_clms = 0
gen pra_pdays = 0
replace pra_clms = praso_clms 
replace pra_pdays = praso_pdays 
replace pra_pdays = 365 if pra_pdays>365

gen rosu_clms = 0
gen rosu_pdays = 0
replace rosu_clms = rosuso_clms 
replace rosu_pdays = rosuso_pdays 
replace rosu_pdays = 365 if rosu_pdays>365

gen sim_clms = 0
gen sim_pdays = 0
replace sim_clms = simso_clms 
replace sim_pdays = simso_pdays 
replace sim_pdays = 365 if sim_pdays>365

gen stat_clms = 0
gen stat_pdays = 0
replace stat_clms = ator_clms + pra_clms + rosu_clms + sim_clms
replace stat_pdays = ator_pdays + pra_pdays + rosu_pdays + sim_pdays
replace stat_pdays = 365 if stat_pdays>365

gen lp_clms = 0
gen lp_pdays = 0 
replace lp_clms = ator_clms + sim_clms
replace lp_pdays = ator_pdays + sim_pdays
replace lp_pdays = 365 if lp_pdays>365

gen hp_clms = 0
gen hp_pdays = 0 
replace hp_clms = pra_clms + rosu_clms
replace hp_pdays = pra_pdays + rosu_pdays
replace hp_pdays = 365 if hp_pdays>365

//user vars
// note: user vars in the bigger categories pick up people that fall into none of the sub-categories. 
local vars "ator pra rosu sim stat lp hp"
foreach i in `vars'{
	gen `i'_user = 0
	replace `i'_user = 1 if `i'_pdays>=180 & `i'_clms>=2
}

//lag vars
foreach i in `vars'{
	gen `i'_user_L1 = 0
	replace `i'_user_L1 = 1 if `i'_pdays[_n-1]>=180 & `i'_clms[_n-1]>=2 & bene_id==bene_id[_n-1]
	replace `i'_user_L1 = . if year==2007
	
	gen `i'_user_L12 = 0
	replace `i'_user_L12 = 1 if `i'_pdays[_n-1]>=180 & `i'_pdays[_n-2]>=180 & `i'_clms[_n-1]>=2 & `i'_clms[_n-2]>=2 & bene_id==bene_id[_n-1] & bene_id==bene_id[_n-2]
	replace `i'_user_L12 = . if year==2007 | year==2008  

	gen `i'_user_L2 = 0
	replace `i'_user_L2 = 1 if `i'_pdays[_n-2]>=180 & `i'_clms[_n-2]>=2 & bene_id==bene_id[_n-2]
	replace `i'_user_L2 = . if year==2007 | year==2008  
}

////////////	Current
gen classcountstat = 0
replace classcountstat = ator_user + pra_user + rosu_user + sim_user

gen anystat_solo = 0
replace anystat_solo = 1 if classcountstat==1

gen anystat_combo = 0
replace anystat_combo = 1 if classcountstat>1 & classcountstat!=.

////////////	L1
gen classcountstat_L1 = 0
replace classcountstat_L1 = ator_user_L1 + pra_user_L1 + rosu_user_L1 + sim_user_L1

gen anystat_solo_L1 = 0
replace anystat_solo_L1 = 1 if classcountstat_L1==1

gen anystat_combo_L1 = 0
replace anystat_combo_L1 = 1 if classcountstat_L1>1 & classcountstat_L1!=.

//L2
gen classcountstat_L2 = 0
replace classcountstat_L2 = ator_user_L2 + pra_user_L2 + rosu_user_L2 + sim_user_L2

////////////	L12
gen classcountstat_L12 = 0
replace classcountstat_L12 = ator_user_L12 + pra_user_L12 + rosu_user_L12 + sim_user_L12

gen anystat_solo_L12 = 0
replace anystat_solo_L12 = 1 if classcountstat_L12==1

gen anystat_combo_L12 = 0
replace anystat_combo_L12 = 1 if classcountstat_L12>1 & classcountstat_L12!=.

//////////////  Any 1 stat at the threshold
//any of the other 4
gen stat1_user = 0
replace stat1_user = 1 if ator_user==1 | pra_user==1 | rosu_user==1 | sim_user==1
gen stat1_user_L12 = 0
replace stat1_user_L12 = 1 if ator_user_L12==1 | pra_user_L12==1 | rosu_user_L12==1 | sim_user_L12==1

////////////////////////////////////////////////////////////////////////////////
///////////////////////    	STATINS-AHT COMBOS      ////////////////////////////
////////////////////////////////////////////////////////////////////////////////
/*
Make 28 combo variables for L12 for interactions of:
	7 statins: stat1 lp hp ator pra rosu sim
	8 ahts: ras oth4 acei a2rb bblo cchb loop thia
*/
gen int_stat1_ras_L12 = 0
replace int_stat1_ras_L12 = 1 if stat1_user_L12==1 & ras_user_L12==1
gen int_lp_ras_L12 = 0
replace int_lp_ras_L12 = 1 if lp_user_L12==1 & ras_user_L12==1
gen int_hp_ras_L12 = 0
replace int_hp_ras_L12 = 1 if hp_user_L12==1 & ras_user_L12==1
gen int_ator_ras_L12 = 0
replace int_ator_ras_L12 = 1 if ator_user_L12==1 & ras_user_L12==1
gen int_pra_ras_L12 = 0
replace int_pra_ras_L12 = 1 if pra_user_L12==1 & ras_user_L12==1
gen int_rosu_ras_L12 = 0
replace int_rosu_ras_L12 = 1 if rosu_user_L12==1 & ras_user_L12==1
gen int_sim_ras_L12 = 0
replace int_sim_ras_L12 = 1 if sim_user_L12==1 & ras_user_L12==1

gen int_stat1_oth4_L12 = 0
replace int_stat1_oth4_L12 = 1 if stat1_user_L12==1 & oth4_user_L12==1
gen int_lp_oth4_L12 = 0
replace int_lp_oth4_L12 = 1 if lp_user_L12==1 & oth4_user_L12==1
gen int_hp_oth4_L12 = 0
replace int_hp_oth4_L12 = 1 if hp_user_L12==1 & oth4_user_L12==1
gen int_ator_oth4_L12 = 0
replace int_ator_oth4_L12 = 1 if ator_user_L12==1 & oth4_user_L12==1
gen int_pra_oth4_L12 = 0
replace int_pra_oth4_L12 = 1 if pra_user_L12==1 & oth4_user_L12==1
gen int_rosu_oth4_L12 = 0
replace int_rosu_oth4_L12 = 1 if rosu_user_L12==1 & oth4_user_L12==1
gen int_sim_oth4_L12 = 0
replace int_sim_oth4_L12 = 1 if sim_user_L12==1 & oth4_user_L12==1

gen int_stat1_acei_L12 = 0
replace int_stat1_acei_L12 = 1 if stat1_user_L12==1 & acei_user_L12==1
gen int_lp_acei_L12 = 0
replace int_lp_acei_L12 = 1 if lp_user_L12==1 & acei_user_L12==1
gen int_hp_acei_L12 = 0
replace int_hp_acei_L12 = 1 if hp_user_L12==1 & acei_user_L12==1
gen int_ator_acei_L12 = 0
replace int_ator_acei_L12 = 1 if ator_user_L12==1 & acei_user_L12==1
gen int_pra_acei_L12 = 0
replace int_pra_acei_L12 = 1 if pra_user_L12==1 & acei_user_L12==1
gen int_rosu_acei_L12 = 0
replace int_rosu_acei_L12 = 1 if rosu_user_L12==1 & acei_user_L12==1
gen int_sim_acei_L12 = 0
replace int_sim_acei_L12 = 1 if sim_user_L12==1 & acei_user_L12==1

gen int_stat1_a2rb_L12 = 0
replace int_stat1_a2rb_L12 = 1 if stat1_user_L12==1 & a2rb_user_L12==1
gen int_lp_a2rb_L12 = 0
replace int_lp_a2rb_L12 = 1 if lp_user_L12==1 & a2rb_user_L12==1
gen int_hp_a2rb_L12 = 0
replace int_hp_a2rb_L12 = 1 if hp_user_L12==1 & a2rb_user_L12==1
gen int_ator_a2rb_L12 = 0
replace int_ator_a2rb_L12 = 1 if ator_user_L12==1 & a2rb_user_L12==1
gen int_pra_a2rb_L12 = 0
replace int_pra_a2rb_L12 = 1 if pra_user_L12==1 & a2rb_user_L12==1
gen int_rosu_a2rb_L12 = 0
replace int_rosu_a2rb_L12 = 1 if rosu_user_L12==1 & a2rb_user_L12==1
gen int_sim_a2rb_L12 = 0
replace int_sim_a2rb_L12 = 1 if sim_user_L12==1 & a2rb_user_L12==1

gen int_stat1_bblo_L12 = 0
replace int_stat1_bblo_L12 = 1 if stat1_user_L12==1 & bblo_user_L12==1
gen int_lp_bblo_L12 = 0
replace int_lp_bblo_L12 = 1 if lp_user_L12==1 & bblo_user_L12==1
gen int_hp_bblo_L12 = 0
replace int_hp_bblo_L12 = 1 if hp_user_L12==1 & bblo_user_L12==1
gen int_ator_bblo_L12 = 0
replace int_ator_bblo_L12 = 1 if ator_user_L12==1 & bblo_user_L12==1
gen int_pra_bblo_L12 = 0
replace int_pra_bblo_L12 = 1 if pra_user_L12==1 & bblo_user_L12==1
gen int_rosu_bblo_L12 = 0
replace int_rosu_bblo_L12 = 1 if rosu_user_L12==1 & bblo_user_L12==1
gen int_sim_bblo_L12 = 0
replace int_sim_bblo_L12 = 1 if sim_user_L12==1 & bblo_user_L12==1

gen int_stat1_cchb_L12 = 0
replace int_stat1_cchb_L12 = 1 if stat1_user_L12==1 & cchb_user_L12==1
gen int_lp_cchb_L12 = 0
replace int_lp_cchb_L12 = 1 if lp_user_L12==1 & cchb_user_L12==1
gen int_hp_cchb_L12 = 0
replace int_hp_cchb_L12 = 1 if hp_user_L12==1 & cchb_user_L12==1
gen int_ator_cchb_L12 = 0
replace int_ator_cchb_L12 = 1 if ator_user_L12==1 & cchb_user_L12==1
gen int_pra_cchb_L12 = 0
replace int_pra_cchb_L12 = 1 if pra_user_L12==1 & cchb_user_L12==1
gen int_rosu_cchb_L12 = 0
replace int_rosu_cchb_L12 = 1 if rosu_user_L12==1 & cchb_user_L12==1
gen int_sim_cchb_L12 = 0
replace int_sim_cchb_L12 = 1 if sim_user_L12==1 & cchb_user_L12==1

gen int_stat1_loop_L12 = 0
replace int_stat1_loop_L12 = 1 if stat1_user_L12==1 & loop_user_L12==1
gen int_lp_loop_L12 = 0
replace int_lp_loop_L12 = 1 if lp_user_L12==1 & loop_user_L12==1
gen int_hp_loop_L12 = 0
replace int_hp_loop_L12 = 1 if hp_user_L12==1 & loop_user_L12==1
gen int_ator_loop_L12 = 0
replace int_ator_loop_L12 = 1 if ator_user_L12==1 & loop_user_L12==1
gen int_pra_loop_L12 = 0
replace int_pra_loop_L12 = 1 if pra_user_L12==1 & loop_user_L12==1
gen int_rosu_loop_L12 = 0
replace int_rosu_loop_L12 = 1 if rosu_user_L12==1 & loop_user_L12==1
gen int_sim_loop_L12 = 0
replace int_sim_loop_L12 = 1 if sim_user_L12==1 & loop_user_L12==1

gen int_stat1_thia_L12 = 0
replace int_stat1_thia_L12 = 1 if stat1_user_L12==1 & thia_user_L12==1
gen int_lp_thia_L12 = 0
replace int_lp_thia_L12 = 1 if lp_user_L12==1 & thia_user_L12==1
gen int_hp_thia_L12 = 0
replace int_hp_thia_L12 = 1 if hp_user_L12==1 & thia_user_L12==1
gen int_ator_thia_L12 = 0
replace int_ator_thia_L12 = 1 if ator_user_L12==1 & thia_user_L12==1
gen int_pra_thia_L12 = 0
replace int_pra_thia_L12 = 1 if pra_user_L12==1 & thia_user_L12==1
gen int_rosu_thia_L12 = 0
replace int_rosu_thia_L12 = 1 if rosu_user_L12==1 & thia_user_L12==1
gen int_sim_thia_L12 = 0
replace int_sim_thia_L12 = 1 if sim_user_L12==1 & thia_user_L12==1

////////////////////////////////////////////////////////////////////////////////
///////////////////////    		AD VARIABLES       	////////////////////////////
////////////////////////////////////////////////////////////////////////////////

local adrd "ADv ADRDv NADDccw ADccw ADRDccw"
foreach i in `adrd'{
	gen `i'_inc = 0
	replace `i'_inc = 1 if `i'_year==year 
	replace `i'_inc = 2 if `i'_year<year 
}

//Comorbidities prior to year t, all based on ccw
gen cmd_ami = 0 
gen cmd_atf = 0 
gen cmd_dia = 0 
gen cmd_str = 0 
gen cmd_hyp = 0 
gen cmd_hyperl = 0 
replace cmd_ami = 1 if year(amie)<year
replace cmd_atf = 1 if year(atrialfe)<year
replace cmd_dia = 1 if year(diabtese)<year
replace cmd_str = 1 if year(strktiae)<year
replace cmd_hyp = 1 if year(hyperte)<year
replace cmd_hyperl = 1 if year(hyperle)<year

gen cmd_NADD = 0
replace cmd_NADD = 1 if NADDccw_inc==2

gen ys_hypert = 0
replace ys_hypert = year-year(hyperte)
replace ys_hypert = 0 if ys_hypert<0
replace ys_hypert = 0 if ys_hypert==.

gen ys_hyperl = 0
replace ys_hyperl = year-year(hyperle)
replace ys_hyperl = 0 if ys_hyperl<0
replace ys_hyperl = 0 if ys_hyperl==.

compress
save "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/aht/statins+aht/statinsaht_long0714c1802.dta", replace
*/
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//																			  //
//			bene level variables on treatment, controls, outcomes			  //
//																			  //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
use "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/aht/statins+aht/statinsaht_long0714c1802.dta", replace
egen idn = group(bene_id)

//treatment - ever user (ever 2 claims in a single year), ever high
// note: user vars in the bigger categories pick up people that fall into none of the sub-categories. 
local vars "aht ras acei a2rb bblo cchb loop thia adrx ator pra rosu sim stat"
foreach i in `vars'{
	egen `i'_user_ever = max(`i'_user), by(bene_id)
	//egen `i'_high_ever = max(`i'_high), by(bene_id)
}

//outcome - ever any of the diagnoses
local adrd "ADv ADRDv NADDccw ADccw ADRDccw"
foreach i in `adrd'{
	gen `i'_ever = .
	replace `i'_ever = 1 if `i'_inc==1 | `i'_inc==2
}
xfill ADv_ever ADRDv_ever NADDccw_ever ADccw_ever ADRDccw_ever, i(idn)
foreach i in `adrd'{
	replace `i'_ever = 0 if `i'_ever==.
}

//controls - age female race_d* hcc_comm cmd_* pct_hsgrads 
//		(prioritizing earliest value of time-variant variables)
gen agesq = age^2

gen age1 = age if year==2007
gen hcc_comm1 = hcc_comm if year==2007
gen pct_hsgrads1 = pct_hsgrads if year==2007
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2008 & age1==.
replace hcc_comm1 = hcc_comm if year==2008 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2008 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2009 & age1==.
replace hcc_comm1 = hcc_comm if year==2009 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2009 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2010 & age1==.
replace hcc_comm1 = hcc_comm if year==2010 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2010 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2011 & age1==.
replace hcc_comm1 = hcc_comm if year==2011 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2011 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2012 & age1==.
replace hcc_comm1 = hcc_comm if year==2012 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2012 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2013 & age1==.
replace hcc_comm1 = hcc_comm if year==2013 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2013 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)
replace age1 = age if year==2014 & age1==.
replace hcc_comm1 = hcc_comm if year==2014 & hcc_comm1==.
replace pct_hsgrads1 = pct_hsgrads if year==2014 & pct_hsgrads1==.
xfill age1 hcc_comm1 pct_hsgrads1, i(idn)


local cmd "ami atf dia str hyp hyperl"
foreach i in `cmd'{
	gen `i'_ever = .
	replace `i'_ever = 1 if cmd_`i'==1
}
xfill ami_ever atf_ever dia_ever str_ever hyp_ever hyperl_ever, i(idn)
foreach i in `cmd'{
	replace `i'_ever = 0 if `i'_ever==.
}

//used AChEI or memantine prior to reference year
gen adrx_prior = 0
replace adrx_prior = 1 if adrx_clms[_n-1]>=2 & bene_id==bene_id[_n-1]
replace adrx_prior = 1 if adrx_clms[_n-2]>=2 & bene_id==bene_id[_n-2]
replace adrx_prior = 1 if adrx_clms[_n-3]>=2 & bene_id==bene_id[_n-3]
replace adrx_prior = 1 if adrx_clms[_n-4]>=2 & bene_id==bene_id[_n-4]
replace adrx_prior = 1 if adrx_clms[_n-5]>=2 & bene_id==bene_id[_n-5]
replace adrx_prior = 1 if adrx_clms[_n-6]>=2 & bene_id==bene_id[_n-6]

drop idn

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//																			  //
//			Long file of statins/AHT use, AD incidence, and controls 		  //
//																			  //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

/*
Note that this file includes observations for people after they get ADRD (or whatever).
It also includes obs for people in the year that they die. 
In subsequent files, you need to drop the observations that occur after the diagnosis of interest.
Maybe also drop dying people.

This file also includes all the people who got AD 1999-2007 (not picked up in the ADv variable)
*/
compress
save "/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/AD/data/aht/statins+aht/statinsaht_long0714_1802.dta", replace

