
# generate kegg.1e-10.overlap
ruby ~/project/Rhizobiales/scripts/ortho2cdd/getBlastCogOverlap.rb --blast_dir ~/project/Brady/results/kegg/kegg_diamond/ --cdd_db ~/project/Rhizobiales/scripts/ortho2cdd/kegg.sqlite3 --orthogroup ../../../../AOE/results/of/protein/OrthoFinder/Results_Aug10/Orthogroups/Orthogroups.tsv --cpu 16 --type kegg -e 1e-10 | sponge kegg.1e-10.overlap

# generate ortho2kegg.tbl 
~/project/Rhizobiales/scripts/ortho2cdd/getOrtho2FamFromCogOverlap.rb -i kegg.1e-10.overlap > ortho2kegg.tbl

# generate final result like 
cut -f1 kegg.1e-10.overlap | ruby ~/project/Rhizobiales/scripts/ortho2cdd/parseGeneGainLossOrtho.rb -i ortho2kegg.tbl --fam_list - > xixi

