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
drop if ADRDccw_inc==2  

//drop the obs for people that died in that year
drop if death_year==year
drop if death_year<year

//keep only the obs in the long file where the person used a class of both in years t-1 and t-2
keep if (acei_user_L12==1 | a2rb_user_L12==1 | bblo_user_L12==1 | cchb_user_L12==1 | loop_user_L12==1 | thia_user_L12==1)

//no one has NADD before the beginning of the year
//drop cmd_NADD

//drop hypertension variable
drop cmd_hyp

//drop those that used an AChEI or memantine prior to reference year
drop if adrx_prior==1
count
codebook bene_id

//setup outsum
outsum female using "./output/sum_saht2a1_adrdv.xls", ctitle(SETUP 1) replace

////////////////////////////////////////////////////////////////////////////////
// 		General statin use among the AHT users								  //
////////////////////////////////////////////////////////////////////////////////
local stat "stat ator pra rosu sim"
foreach i in `stat'{
	outsum `i'_user using "./output/sum_saht2a1_adrdv.xls", ctitle(AHT) append
	outsum `i'_user if ras_user==1 using "./output/sum_saht2a1_adrdv.xls", ctitle(RAS) append
	outsum `i'_user if ras_user==0 using "./output/sum_saht2a1_adrdv.xls", ctitle(noRAS) append
	outsum `i'_user if acei_user==1 using "./output/sum_saht2a1_adrdv.xls", ctitle(ACEI) append
	outsum `i'_user if a2rb_user==1 using "./output/sum_saht2a1_adrdv.xls", ctitle(ARB) append
	outsum `i'_user if oth4_user==1 using "./output/sum_saht2a1_adrdv.xls", ctitle(Other 4) append
}

////////////////////////////////////////////////////////////////////////////////
// 		General sum stats for the statins-aht sample						  //
////////////////////////////////////////////////////////////////////////////////
keep if (ator_user_L12==1 | pra_user_L12==1 | rosu_user_L12==1 | sim_user_L12==1)
keep if classcountstat_L12==1
count
codebook bene_id

//follow-up time
egen yearf = min(year), by(bene_id)
egen yearl = max(year), by(bene_id)
gen follow = yearl-yearf+1


////////	Outcome and controls
codebook bene_id 

codebook bene_id if ras_user==1 
codebook bene_id if ras_user==1 & ator_user==1 
codebook bene_id if ras_user==1 & pra_user==1  
codebook bene_id if ras_user==1 & rosu_user==1 
codebook bene_id if ras_user==1 & sim_user==1  

codebook bene_id if ras_user==0 
codebook bene_id if ras_user==0 & ator_user==1 
codebook bene_id if ras_user==0 & pra_user==1  
codebook bene_id if ras_user==0 & rosu_user==1 
codebook bene_id if ras_user==0 & sim_user==1  

codebook bene_id if acei_user==1 
codebook bene_id if acei_user==1 & ator_user==1 
codebook bene_id if acei_user==1 & pra_user==1  
codebook bene_id if acei_user==1 & rosu_user==1 
codebook bene_id if acei_user==1 & sim_user==1  

codebook bene_id if a2rb_user==1 
codebook bene_id if a2rb_user==1 & ator_user==1 
codebook bene_id if a2rb_user==1 & pra_user==1  
codebook bene_id if a2rb_user==1 & rosu_user==1 
codebook bene_id if a2rb_user==1 & sim_user==1  

codebook bene_id if oth4_user==1 
codebook bene_id if oth4_user==1 & ator_user==1 
codebook bene_id if oth4_user==1 & pra_user==1  
codebook bene_id if oth4_user==1 & rosu_user==1 
codebook bene_id if oth4_user==1 & sim_user==1  

codebook bene_id if ator_user==1 
codebook bene_id if pra_user==1  
codebook bene_id if rosu_user==1 
codebook bene_id if sim_user==1  
