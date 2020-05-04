#! /usr/bin/env ruby


#####################################################
dir = File.dirname($0)
$: << File.join(dir, 'lib')


#####################################################
require 'getoptlong'
require 'sqlite3'
require 'parallel'

require 'util'
require 'Dir'
require 'chang_yong'
require 'readOrthogroup'
require 'seqIO'
require 'kegg'


#####################################################
$KEGG_DIR = File.expand_path("~/resource/db/kegg/v2017")
$KEGG_GENE_2_ORTHO = File.join($KEGG_DIR, 'kegg_bacteria.gene2ko')


#####################################################
infile = nil
type = nil
db_file = nil
cdd_db_file = nil
orthogroupFile = nil
blast_indirs = Array.new
blast8_files = Array.new
include_list_file = nil
suffix = nil
evalue_cutoff = 1e-5
is_bitscore = false
cpu = 2
is_force = false

gene2ortho = Hash.new


#####################################################
def readCddSqlite3(db_file)
  cdd_info = Hash.new{|h,k|h[k]={}}
  db = SQLite3::Database.open(db_file)

  query = "select * from \"cdd\""
  db.execute(query) do |result|
    cdd = result[0]
    %w[cdd name gene prot length bitscore].each_with_index do |ele, index|
      cdd_info[cdd][ele.to_sym] = result[index]
    end
  end  

  return(cdd_info)
end


def filterCddBasedOnCdd(name, type)
  rv = false
  case type
    when /pfam/i
      rv = name =~ /^pfam/i ? true : false
    when /COG/i
      rv = name =~ /^COG/i ? true : false
    when /TIGRFAM/i
      rv = name =~ /^TIGR/i ? true : false
    when /PRK/i
      rv = name =~ /^PRK/ ? true : false
    when /cd/i
      rv = name =~ /^cd/ ? true : false
    when /kegg/i
      rv = name =~ /^K/ ? true : false
  end
  return(rv) 
end


def getGeneCddInfo(infiles, type, cdd_info, gene2ortho, evalue_cutoff, is_bitscore, cpu)
  results = Parallel.map(infiles, in_processes: cpu) do |infile|
    tmpGeneCddInfo = Hash.new
    tmpBitScoreInfo = Hash.new
    taxon = getCorename(infile)
    in_fh = File.open(infile, 'r')
    in_fh.each do |line|
      line.chomp!
      next if line =~ /^#/
      if type == 'pfam123'
        line_arr = line.split(/\s+/)
        gene, pfam_name, pfam_id, evalue, bitscore = line_arr.values_at(0,3,4,6,7)
        pfam_id = pfam_id.split('.')[0] # change pfam_id
        evalue = evalue.to_f
        bit_score = bitscore.to_f
        next if bit_score.nil?
        next if evalue > evalue_cutoff
        tmpGeneCddInfo[gene] = Array.new if not tmpGeneCddInfo.include?(gene)
        tmpGeneCddInfo[gene] << pfam_id
        tmpBitScoreInfo[gene] = Hash.new if not tmpBitScoreInfo.include?(gene)
        tmpBitScoreInfo[gene][pfam_id] = bitscore
      else
        #Bradyrhizobium_canariense_UBMA171|BSZ22_RS01850	gnl|CDD|223180	42.42	33	14	1	58	85	77	109	4e-04	28.0
        line_arr = line.split("\t")
        gene,cdd_full,evalue,bitscore  = line_arr.values_at(0,1,10,11)
        if type == 'kegg'
          cdd = gene2ortho[cdd_full]
        else
          cdd = cdd_full.split('|')[-1].split(':')[-1] #change
        end
        evalue = evalue.to_f
        bitscore = bitscore.to_f
        next if evalue > evalue_cutoff
        v = cdd_info[cdd]
        next if v[:bitscore].nil?
        if is_bitscore
          next if bitscore < v[:bitscore]
        end
        #taxon = gene.split('|')[0]
        next if not filterCddBasedOnCdd(v[:name], type)
        next if v[:name].nil?
        tmpGeneCddInfo[gene] = Array.new if not tmpGeneCddInfo.include?(gene)
        tmpGeneCddInfo[gene] << v[:name]
        tmpBitScoreInfo[gene] = Hash.new if not tmpBitScoreInfo.include?(gene)
        tmpBitScoreInfo[gene][v[:name]] = bitscore
      end
    end
    in_fh.close

    tmpGeneCddInfo.each_pair do |gene, names|
      names = names.sort_by{|name|tmpBitScoreInfo[gene][name]}.reverse
      tmpGeneCddInfo[gene] = names[0]
      exit if names[0].nil?
    end
    tmpGeneCddInfo
  end

  geneCddInfo = Hash.new
  results.each do |tmpGeneCddInfo|
    geneCddInfo.merge!(tmpGeneCddInfo)
  end
  return(geneCddInfo)
end


def assessConsistencyOfOrthogroup(orthogroup_info, geneCddInfo)
  orthogroup_info.each_pair do |orthogroup, v|
    cogs = Array.new
    v.each_pair do |species, genes|
      genes.each do |gene|
        cogs << geneCddInfo[gene] if geneCddInfo.include?(gene)
      end
    end
    cogs.flatten!
    output_arr = cogs.inject(Hash.new(0)){|h,e|h[e]+=1;h}.sort{|a,b|a[1]<=>b[1]}.reverse.map{|a|a.join(',')}
    puts [orthogroup, v.values.flatten.size, cogs.size, output_arr].flatten.join("\t")
  end
end


#####################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--type', GetoptLong::REQUIRED_ARGUMENT],
  ['--cdd_db', GetoptLong::REQUIRED_ARGUMENT],
  ['--db', GetoptLong::REQUIRED_ARGUMENT],
  ['--orthogroup', GetoptLong::REQUIRED_ARGUMENT],
  ['--blast_indir', '--blast_dir', GetoptLong::REQUIRED_ARGUMENT],
  ['--include_list', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['-e', '--evalue', GetoptLong::REQUIRED_ARGUMENT],
  ['--bitscore', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      infile = value
    when /^--type$/
      type = value
    when /^--db$/
      db_file = value
    when /^--cdd_db$/
      cdd_db_file = value
    when /^--orthogroup$/
      orthogroupFile = value
    when /^--(blast_dir|blast_indir)$/
      blast_indirs << value.split(',')
    when /^--include_list$/
      include_list_file = value
    when /^--suffix$/
      suffix = value
    when /^-e|--evlaue$/
      evalue_cutoff = value.to_f
    when /^--bitscore$/
      is_bitscore = true
    when /^--cpu$/
      cpu = value.to_i
    when /^--force$/
      is_force = true
  end
end


#####################################################
if include_list_file.nil?
  STDERR.puts "include_list_file1:\tnil"
else
  STDERR.puts "include_list_file:\t#{include_list_file}"
end


#####################################################
blast_indirs.flatten!

if type.nil?
  STDERR.puts "Type has to be given! Exiting ......"
  exit 1
end


#####################################################
if __FILE__ == $0; then
  cdd_info = readCddSqlite3(cdd_db_file)

  gene2ortho = getGene2Ortho($KEGG_GENE_2_ORTHO) if type == 'kegg'

  orthogroup_info = readOrthogroupFile(orthogroupFile)

  species_included = read_list(include_list_file)

  blast_indirs.each do |blast_indir|
    blast8_files << read_infiles(blast_indir)
  end
  blast8_files.flatten!

  blast8_files_good = getFilesGood(blast8_files, species_included, suffix)
  STDERR.puts "blast8 files emtyp! Exiting ......" or exit 1 if blast8_files_good.empty?

  geneCddInfo = getGeneCddInfo(blast8_files_good, type, cdd_info, gene2ortho, evalue_cutoff, is_bitscore, cpu)

  assessConsistencyOfOrthogroup(orthogroup_info, geneCddInfo)
end


