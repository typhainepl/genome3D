# Mapping process

## Configuration
Need to create ***config.pl*** file where to write information about database connexion for pdbe_test (db, user and password) in the ***config*** directory

Need to create a schema under pdbe_test in Oracle SGBD

Main program is ***mapping_process.pl*** <br>
All the files generated are wrote under MDA_results/CATH_4_1 directory

## Get data from SIFTS table (*get_segment.pm*)
- Get different PDB entries data from SIFTS_ADMIN_NEW.ENTITY_CATH and SIFTS_ADMIN_NEW.ENTITY_SCOP tables
- Import in SEGMENT_CATH and SEGMENT_SCOP
- Aggregate data from the both tables on ```auth_asym_id``` in SEGMENT_CATH_SCOP

## Domain mapping (*domain_mapping.pm*)
- Compare start/end residue numbers
- Calculate percentage and overlapping for domains
- Enter data in DOMAIN_MAPPING

## Node mapping (*node_mapping.pm*)
Calculate percentage, overlapping, medals for nodes (superfamilies) <br>
If sequence coverage by CATH domain and by SCOP domain > 25% => enter data in NODE_MAPPING

## Clustering (*clustering.pm*)
Clustering nodes using DOMAIN_MAPPING and NODE_MAPPING <br>
If average domain coverage at SF level > 25% and overlapping between CATH and SCOP > 25% => enter data in CLUSTER

## MDA blocks (*get_mda_blocks.pm*)
Determine MDA blocks for each cluster (MDA block is a sequence of following CATH and SCOP domain superfamilies) <br>
If overlapping between CATH and SCOP > 50% => enter data in MDA_BLOCKS with different CATH and SCOP domains begin-end positions
Link with cluster in CLUSTER_BLOCK table

## Get chain and uniprot IDs (*get_mda_blocks.pm*)
- For each MDA block, get chains ID with uniprot ID and uniprot sequence coverage percentage by the chain corresponding
- Enter data into BLOCK_CHAIN and BLOCK_UNIPROT tables
- Write mda_blocks.list (uniprot with number of chain for each block) and mda_info.list (for each uniprot in each block: chain and coverage)

## Determine subcategories (*get_chop_homo.pm*)
chopping: equivalence split, one instance, class4...<br>
homology differences<br>
Write info in files


## CATH/ECOD mapping
Main program is ***mapping_process_ecod.pl*** <br>
All the files generated are wrote under MDA_results/CATH_ECOD directory <br>
The mapping process is the same as the CATH/SCOP mapping above, but just replacing SCOP data by ECOD data and the tables names have _ECOD added at the end<br>
It needs an extra step which is getting ECOD data from the ECOD website (http://prodata.swmed.edu/ecod/distribution/ecod.latest.domains.txt). This step is executed using a python program under the ***update_database*** directory.
