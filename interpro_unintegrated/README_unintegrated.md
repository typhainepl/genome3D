# Get list of unintegrated Gene3D and SUPERFAMILY in InterPro, adapted to the creation of genome3d trac pages tables

Need to create *db.cfg* file where to write information about database connexion for pdbe_test (pdbeUser, pdbePass and pdbeHost)
and interpro (ipproUser,ipproPass and ipproHost)

Main program is *get_particular_block.py*, it calls *search_unintegrated.py*

## Running the program
The main program must be run with 2 arguments:
- number
	1. gold block
	2. 2domains-1domain same SF
	3. 2domains different SF-1domain
- name of file <br>
  Where the program will write unintegrated superfamilies (will be wrote in the unintegrated directory)

## Progress of the script
1. Get the different clusters (```getCluster```)
2. For each cluster which match the conditions corresponding to the number specified, get the different blocks (```getUnintegratedBlocks```)
3. For each block:<br>
	- search if gold (same number of CATH and SCOP SF in cluster and same number of CATH and SCOP in block)
	- search if one to many domains (if CATH/SCOP is split in multiple domains (without other domain from an unknown SF between domains) while SCOP/CATH has only one domain)
	- search if unintegrated GENE3D and SUPERFAMILY signatures into InterPro (```getUnintegrated``` in *search_unintegrated.py*)
        - search number of corresponding proteins
        - print unintegrated in file
4. Print number of :
	- unintegrated GENE3D
	- unintegrated SUPERFAMILY
	- unintegrated clusters (pairs)
