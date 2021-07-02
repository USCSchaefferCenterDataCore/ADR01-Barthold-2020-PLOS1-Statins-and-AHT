/*********************************************************************************************/
title1 'NDC By Gname';

* Author: PF;
* Summary: 

•	Input: ndcall_tclass_all_2016_02_10.dta
•	Output: just log
•	Gets NDCs associated with gnames 
		note: ndcs associated with class variables should come from fdb_ndc_extract.dta (see ndcbyclass.do);

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict 
	mergenoby=warn varlenchk=error varinitchk=error dkrocond=error msglevel=i mprint;
/*********************************************************************************************/

%include "../../../../../51866/PROGRAMS/setup.inc";
libname ndc "&datalib.Clean_Data/DrugInfo/";

* create temporary data set;
data ndcall;
	set ndc.ndcall_tclass_all_2016_02_10;
run;

* creating macros for subsequent frequencies, in order to just replace string of interest;

* macro for combos finding both unique gname and ndc;
%macro combo(str);
proc freq data=ndcall;
	where find(gname,"&str");
	table gname ndc;
	title3 "&str";
run;
%mend;

* macro for solo, unique ndc where gname = string of interest;
%macro solo(str);
proc freq data=ndcall;
	where gname="&str";
	table ndc;
	title3 "&str";
run;
%mend;

* macro for all other standalone frequences;
%macro freq(str,var);
proc freq data=ndcall;
	where find(gname,"&str");
	table &var;
	title3 "&str";
run;
%mend;

/********** ARBS **********/
%freq(SACUBITRIL,gname);

proc freq data=ndcall ;
	where ndc in("00078065920","00078065935","00078065961",
	"00078065967","00078069620","00078069635","00078069661",
	"00078069667","00078077720","00078077735","00078077761",
	"00078077767");
	table ndc;
run;

proc freq data=ndcall ;
	where ndc in("0078057215","00078057415");
	table gname;
run;

/***** BBB permeability =1 *****/
%combo(CANDESARTAN);
%solo(CANDESARTAN CILEXETIL);

%combo(EPROSARTAN);
%solo(EPROSARTAN MESYLATE);

%combo(IRBESARTAN);
%solo(IRBESARTAN);

%combo(TELMISARTAN);
%solo(TELMISARTAN);

%combo(VALSARTAN);
%solo(VALSARTAN);

/*********** ACE inh ***********/
/***** BBB permeability =1 *****/

%combo(CAPTOPRIL);
%solo(CAPTOPRIL);

%combo(FOSINOPRIL);
%solo(FOSINOPRIL SODIUM);

%combo(LISINOPRIL);
%solo(LISINOPRIL);

%combo(PERINDOPRIL);
%solo(PERINDOPRIL ERBUMINE); * same, no combo;

%combo(RAMIPRIL);
%solo(RAMIPRIL); *same, no combo;

%combo(TRANDOLAPRIL);
%solo(TRANDOLAPRIL);

/***** BBB Permeability =0 *****/
%combo(BENAZEPRIL);
%solo(BENAZEPRIL HCL);

%combo(ENALAPRIL);
proc freq data=ndcall;
	where gname in('ENALAPRIL MALEATE','ENALAPRILAT DIHYDRATE');
	table ndc;
run;

%combo(MOEXIPRIL);
%solo(MOEXIPRIL HCL);

%combo(QUINAPRIL);
%solo(QUINAPRIL HCL);

%combo(IMIDAPRIL);
%solo(IMIDAPRIL);

%freq(BENAZEPRIL HCL,ther_class_fdb);
%freq(MOEXIPRIL HCL,ther_class_fdb);
%freq(QUINAPRIL HCL,ther_class_fdb);


/********** STATINS ***********/
* Atorvastatin ;
* NDCs;
%freq(ATORVASTATIN,gname);
%freq(ATORVASTATIN CALCIUM,ndc);
%freq(AMLODIPINE/ATORVASTATIN,ndc);

	* Classes - since my freq is already shows the results of the tab function
	in original stata program, only doing freq here instead of tab & levelsof;
	%freq(ATORVASTATIN,ther_class_fdb);
	%freq(ATORVASTATIN,ther_class_ims);
	%freq(ATORVASTATIN,ther_class_rxn);

* Fluvastatin;
* NDCs;
%freq(FLUVASTATIN,gname);
%freq(FLUVASTATIN,ndc);

	* Classes;
	%freq(FLUVASTATIN,ther_class_fdb);
	%freq(FLUVASTATIN,ther_class_ims);
	%freq(FLUVASTATIN,ther_class_rxn);

* Lovastatin;
* NDCs;
%combo(LOVASTATIN);
%solo(NIACIN/LOVASTATIN);

	* Classes;
	%freq(LOVASTATIN,ther_class_fdb);
	%freq(LOVASTATIN,ther_class_ims);
	%freq(LOVASTATIN,ther_class_rxn);

* Pitavastatin;
* NDCs;
%freq(PITAVASTATIN,gname);
%freq(PITAVASTATIN CALCIUM,ndc);

	* Classes;
	%freq(PITAVASTATIN,ther_class_fdb);
	%freq(PITAVASTATIN,ther_class_ims);
	%freq(PITAVASTATIN,ther_class_rxn);
	
* Pravastatin;
%freq(PRAVASTATIN,gname);
%freq(PRAVASTATIN SODIUM,ndc);

proc freq data=ndcall;
	where find(gname,"ASPIRIN(CALC&MG)/PRAVASTATIN");
	table ndc;
run;

	* Classes;
	%freq(PRAVASTATIN,ther_class_fdb);
	%freq(PRAVASTATIN,ther_class_ims);
	%freq(PRAVASTATIN,ther_class_rxn);
	
* Rosuvastatin;
* NDCs;
%freq(ROSUVASTATIN,gname);
%freq(ROSUVASTATIN CALCIUM,ndc);

	* Classes;
	%freq(ROSUVASTATIN,ther_class_fdb);
	%freq(ROSUVASTATIN,ther_class_ims);
	%freq(ROSUVASTATIN,ther_class_rxn);
	
* Simvastatin;
* NDCs;
%combo(SIMVASTATIN);
%solo(EZETIMIBE/SIMVASTATIN);
%solo(NIACIN/SIMVASTATIN);
%solo(SITAGLIPTIN/SIMVASTATIN);

	* Classes;
	%freq(SIMVASTATIN,ther_class_fdb);
	%freq(SIMVASTATIN,ther_class_ims);
	%freq(SIMVASTATIN,ther_class_rxn);
	
/********** PPIS ***********/
* omeprazole, pantoprazole, lansoprazole, esomeprazole, rabeprazole;

%freq(OMEPRAZOLE,gname);
proc freq data=ndcall;
	where gname in('OMEPRAZOLE','OMEPRAZOLE MAGNESIUM','OMEPRAZOLE/CLARITH/AMOXICILLIN','OMEPRAZOLE/SODIUM BICARBONATE');
	table ndc;
run;

%combo(PANTOPRAZOLE);

%combo(LANSOPRAZOLE);

%combo(ESOMEPRAZOLE);

%combo(RABEPRAZOLE);

/********** AD Drugs ***********/

* Donepezil HCL;
 %solo(DONEPEZIL HCL);
 
 * Creating macro for AD drug class frequencies;
%macro addrug_class(gname);
proc freq data=ndcall;
	where gname="&gname";
	table ther_class_fdb  ther_class_ims  ther_class_rxn;
	title3 "&gname";
run;
%mend;

%addrug_class(DONEPEZIL HCL);
%addrug_class(GALANTAMINE HBR);
%addrug_class(MEMANTINE HCL);
%addrug_class(RIVASTIGMINE);
%addrug_class(RIVASTIGMINE TARTRATE);
%addrug_class(TACRINE HCL);







