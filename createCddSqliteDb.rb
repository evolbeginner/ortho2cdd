#! /usr/bin/env ruby


######################################################################
require 'getoptlong'

require 'sqlite3'


######################################################################
$CDD_TBL = File.expand_path("~/resource/db/cdd/cddid_all.tbl")
$CDD_BITSCORE_FILE = File.expand_path("~/resource/db/cdd/bitscore_specific_3.16.txt")
$KEGG_TBL = File.expand_path("~/resource/db/kegg/parse/koid_all.tbl")


######################################################################
def read_kegg_tbl(cdd_info)
  in_fh = File.open($KEGG_TBL, 'r')
  in_fh.each_line do |line|
    #K00001	K00001	E1.1.1.1, adh	alcohol dehydrogenase [EC:1.1.1.1]
    line.chomp!
    line_arr = line.split("\t")
    cdd, name, gene, prot = line_arr
    cdd_info[cdd]['cdd'] = cdd
    cdd_info[cdd]['name'] = name
    cdd_info[cdd]['gene'] = gene
    cdd_info[cdd]['prot'] = prot
    cdd_info[cdd]['length'] = 0
    cdd_info[cdd]['bitscore'] = 100
  end
  in_fh.close
  return(cdd_info)  
end


def read_cdd_tbl(cdd_info, is_name=false)
  in_fh = File.open($CDD_TBL, 'r')
  in_fh.each_line do |line|
    #223129	COG0051	RpsJ	Ribosomal protein S10 [Translation, ribosomal structure and biogenesis]. 	104
    line.chomp!
    line_arr = line.split("\t")
    cdd, name, gene, prot, length = line_arr
    cdd = is_name ? name : cdd
    length = length.to_i
    cdd_info[cdd]['cdd'] = cdd
    cdd_info[cdd]['name'] = name
    cdd_info[cdd]['gene'] = gene
    cdd_info[cdd]['prot'] = prot
    cdd_info[cdd]['length'] = length
  end
  in_fh.close
  return(cdd_info)
end


def read_bitscore_file(cdd_info)
  in_fh = File.open($CDD_BITSCORE_FILE, 'r')
  in_fh.each_line do |line|
    #223080	COG0001	388.863
    line.chomp!
    line_arr = line.split("\t")
    cdd, name, bitscore = line_arr
    bit_score = bit_score.to_f
    cdd_info[cdd]['cdd'] = cdd
    cdd_info[cdd]['name'] = name
    cdd_info[cdd]['bitscore'] = bitscore
  end
  in_fh.close
  return(cdd_info)
end


######################################################################
if $0 == __FILE__
  is_create_db = false
  db_file = nil
  is_cdd = false
  is_kegg = false
  is_force = false
  cdd_info = Hash.new{|h,k|h[k]={}}


######################################################################
  opts = GetoptLong.new(
    ['--create_db', GetoptLong::NO_ARGUMENT],
    ['--force', GetoptLong::NO_ARGUMENT],
    ['--db', '--db_file', GetoptLong::REQUIRED_ARGUMENT],
    ['--cdd', GetoptLong::NO_ARGUMENT],
    ['--kegg', GetoptLong::NO_ARGUMENT],
  )


  opts.each do |opt, value|
    case opt
      when /^--create_db$/
        is_create_db = true
      when /^--(db|db_file)$/
        db_file = value
      when /^--cdd$/
        is_cdd = true
      when /^--kegg$/
        is_kegg = true
      when /^--force$/
        is_force = true
    end
  end


  ######################################################################
  if File.exists?(db_file)
    if is_force
      File.delete(db_file)
    else
      raise "db_file #{db_file} has already existed!"
    end
  end
  db = SQLite3::Database.new(db_file)


  ######################################################################
  if is_cdd
    cdd_info = read_cdd_tbl(cdd_info)
    cdd_info = read_bitscore_file(cdd_info)
  elsif is_kegg
    cdd_info = read_kegg_tbl(cdd_info)
  end


  ######################################################################
  result = db.execute <<-SQL
    CREATE TABLE cdd(
      cdd VARCHAR(15),
      name VARCHAR(15),
      gene VARCHAR(15),
      prot VARCHAR(100),
      length INT,
      bitscore FLOAT
    );
  SQL


  insert_query = "INSERT INTO cdd VALUES"
  cdd_info.each_pair do |cdd, v|
    db.execute 'insert into cdd values (?,?,?,?,?,?)', %w[cdd name gene prot length bitscore].map{|i|v[i.to_s]}
  end

end


