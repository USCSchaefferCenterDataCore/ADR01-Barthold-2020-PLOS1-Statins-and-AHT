/*********************************************************************************************/
title1 'NDC By Class';

* Author: PF;
* Summary: 

•	Input: fdb_ndc_extract.dta
•	Output: just log
•	Gets NDCs/classes associated with class variables
•	Examines the different classes that include certain strings, in both the hic3 class variables, and the ahfs class variable. 
		note: ndcs by gname are found in ndcall_tclass_all_2016_02_10.dta (see ndcbygname.do);


options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i mprint;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
libname fdb "&datalib.Extracts/FDB/";

* creating temporary data set;
data fdb_ndc_extract;
	set fdb.fdb_ndc_extract;
run;

* creating macros for subsequent frequencies, in order to just replace string of interest;

%macro freq_hic3(str);
proc freq data=fdb_ndc_extract;
	where find(hic3_desc,"&str.");
	table hic3_desc;
	title3 "HIC3 &str.";
run;
%mend;

%macro freq_ahfs(str);
proc freq data=fdb_ndc_extract;
	where find(ahfs_desc,"&str.");
	table ahfs_desc;
	title3 "AHFS &str.";
run;
%mend;

/********* Diabetes ***********/
* Biguanides - big -hic3;
%freq_hic3(BIGUANIDE);
%freq_ahfs(BIGUANIDE);

* Glucagon-like peptides - glp - hic3;
%freq_hic3(GLUCAGON);
%freq_hic3(GLP);
%freq_ahfs(GLUCAGON);

* Thiazolidinedione - thi -hic3;
%freq_hic3(THIAZOLIDINEDIONE);
%freq_ahfs(THIAZOLIDINEDIONE);

* Insulins - ins- hic3;
%freq_hic3(INSULIN);
%freq_hic3(INSULIN-LIKE GROWTH);
%freq_ahfs(INSULIN);

* Sulfonylureas - sul -ahfs;
%freq_hic3(SULFONYLUREA);
%freq_ahfs(SULFONYLUREA);

* DPP-4 - dpp -hic3;
%freq_hic3(DPP-4);
%freq_ahfs(DPP-4);

* Amylin agonists - amy -hic3 (same as ahfs);
%freq_hic3(AMYLIN);
%freq_ahfs(AMYLIN);

* Metreleptin - met -hic3;
%freq_hic3(LEPTIN);
%freq_ahfs(LEPTIN);

/********* Hypertension ***********/
* ACE inhibitors - ace - hic3;
%freq_hic3(ACE INHIBITOR);

* ARBs -arb - hic3;
%freq_hic3(ANGIOTENSIN II);
%freq_hic3(ANGIOTENSIN REC);
proc freq data=fdb_ndc_extract;
	where hic3_desc="RENIN INHIBITOR,DIRECT & ANGIOTENSIN RECEPT ANTAG.";
	table ndc;
	title3 "NDC ARB";
run;

* Beta-blockers - bbl - hic3;
%freq_hic3(BETA BLO);
%freq_hic3(BETA-ADREN);

* CCBs - ccd - hic3;
proc freq data=fdb_ndc_extract;
	where find(hic3_desc,'CALCIUM CHAN') | find(hic3_desc,'CALC.CHANNEL BLKR') | find(hic3,'CAL.CHANL BLKR');
	table hic3_desc;
	title3 "HIC3 CCBs";
run;

* Loop Diuretics - diu - hic3;
%freq_hic3(LOOP DIURETIC);
%freq_hic3(LOOP);

* Thiazide - thia - hic3;
%freq_hic3(THIAZIDE);

* Neprilysin Inhibitor - nepr - hic3 
	 Appears only in combo with ARB;
%freq_hic3(NEPRILYSIN);
proc freq data=fdb_ndc_extract;
	where find(hic3_desc,'NEPRILYSIN');
	table ndc;
	title3 "NDC Neprilysin";
run;

endsas;
* The rest of the program is commented out in original program;

/********* GERD ************/
* PPIS - ppi - prefer hic3;
%freq_hic3(PROTON);
%freq_ahfs(PROTON);

* Histamine 2 receptor antagonists - hi2 - hic3;
%freq_hic3(HISTAMINE H2);
%freq_ahfs(HISTAMINE H2);

/********* INSOMNIA **********/
* Endocrine-Metabolic Agent - mel - hic3;
%freq_hic3(MELATONIN);
%freq_ahfs(MELATONIN);

* Atypical antipsychotics - aap - hic3;
%freq_hic3(ATYPICAL);
%freq_ahfs(ATYPICAL);

* Benzodiazepine - ben -ahfs;
%freq_hic3(BENZODIAZEPINE);
%freq_ahfs(BENZODIAZEPINE);

* Nonbarbiturate Hypnotic - nbh - hic3;
%freq_hic3(NON-BARB);
%freq_ahfs(HYPNOTIC);

/********* Other Common drugs used by statin users *********/
* Anticonvulsants - acon - hic3;
%freq_hic3(ANTICONVULSANTS);
%freq_ahfs(ANTICONVULSANTS);

* Bone resorption inhibitor - brin - hic3;
%freq_hic3(BONE RESORPTION INHIBITOR);
%freq_ahfs(BONE RESORPTION INHIBITOR);

* Liptotronics - lipo - hic3;
%freq_hic3(LIPOTRONICS);
%freq_ahfs(LIPOTRONICS);

* platelet aggregation inhibitors - pagi - hic3;
%freq_hic3(PLATELET AGGREGATION);
%freq_ahfs(PLATELET AGGREGATION);

* potassium replacements - pota - hic3;
%freq_hic3(POTASSIUM REPLACEMENT);
%freq_ahfs(ANTICONVULSANTS); * PF  - why is this different?;

* Selective serotonin reuptake inhibitors (SSRIs) - ssri - hic3;
%freq_hic3(SSRI);
%freq_ahfs(SSRI);

* Thiazide and related diurectics - thia - hic3;
%freq_hic3(THIAZIDE);
%freq_ahfs(THIAZIDE);

* Thyroid hormones - thyr- hic3;
%freq_hic3(THYROID HORMONE);
%freq_ahfs(THYROID HORMONE);

* Vasodilators, cornonary - vaso - hic3;
%freq_hic3(VASODILATORS);
%freq_ahfs(VASODILATORS);





