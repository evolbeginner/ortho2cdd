#! /usr/bin/env ruby


#####################################################
require 'getoptlong'

require 'sqlite3'


#####################################################
infile = nil
db_file = nil
cdd_db_file = nil
is_create_db = false
is_force = false


#####################################################
def addQuotes(i)
  if i.class == String
    i = ['"', '"'].join(i)
  end
  return(i)
end


#####################################################
def readCddSqlite3(db_file)
  cdd_info = Hash.new{|h,k|h[k]={}}
  db = SQLite3::Database.open(db_file)

  query = "select * from \"cdd\""
  db.execute(query) do |result|
    cdd = result[0]
    %w[cdd name gene prot length bitscore].each_with_index do |ele, index|
      cdd_info[cdd][ele] = result[index]
    end
  end  

  return(cdd_info)
end


#####################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--cdd_db', GetoptLong::REQUIRED_ARGUMENT],
  ['--db', GetoptLong::REQUIRED_ARGUMENT],
  ['--create_db', GetoptLong::NO_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      infile = value
    when /^--db$/
      db_file = value
    when /^--cdd_db$/
      cdd_db_file = value
    when /^--create_db$/
      is_create_db = true
    when /^--force$/
      is_force = true
  end
end


#####################################################
if is_create_db
  db = SQLite3::Database.new(db_file)
else
  if File.exists?(db_file)
    if is_force
      File.delete(db_file)
      db = SQLite3::Database.new(db_file)
    else
      db = SQLite3::Database.open(db_file)
    end
  end
end


result = db.execute <<-SQL
  DROP TABLE IF EXISTS blastRes;
SQL

result = db.execute <<-SQL
  CREATE TABLE blastRes(
    id VARCHAR(100),
    name VARCHAR(15),
    gene VARCHAR(15),
    taxon VARCHAR(50),
    isOutgroup boolean
  );
SQL


#####################################################
cdd_info = readCddSqlite3(cdd_db_file)


#####################################################
in_fh = File.open(infile, 'r')
in_fh.each do |line|
  #Bradyrhizobium_canariense_UBMA171|BSZ22_RS01850	gnl|CDD|223180	42.42	33	14	1	58	85	77	109	4e-04	28.0
  line.chomp!
  line_arr = line.split("\t")
  gene,cdd_full,bitscore  = line_arr.values_at(0,1,-1)
  cdd = cdd_full.split('|')[-1]
  bitscore = bitscore.to_f

  v = cdd_info[cdd]

  if bitscore >= v['bitscore']
    id = gene
    taxon = gene.split('|')[0]
    isOutgroup = 1
    
    values_str = [id, v['name'], v['gene'], taxon, isOutgroup].map{|i|addQuotes(i)}.join(',')
    query = "INSERT INTO blastRes(id,name,gene,taxon,isOutgroup) VALUES(#{values_str});"
    #db.execute(query)
  end
end
in_fh.close


