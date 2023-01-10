#! /usr/bin/env ruby


#######################################################
# enable cdd.tbl or koid_all.tbl


#######################################################
$DIR = File.dirname($0)
$: << $DIR


#######################################################
require 'getoptlong'

require 'chang_yong'
require 'createCddSqliteDb'


#######################################################
$TYPES = %w[TIGRFAM COG pfam PRK cd KEGG]


infile = nil
fam_list_file = nil
types_included = Array.new

fams = Array.new
cdd_info = Hash.new{|h,k|h[k]={}}


#######################################################
def output_result(cdd_info, fams, fam_list_file)
  fams.each do |fam|
    next if not cdd_info.include?(fam) if not fam_list_file.nil?
    puts [fam, %w[gene prot].map{|i|cdd_info[fam][i]} ].join("\t")
  end
end


#######################################################
if __FILE__ == $0
  opts = GetoptLong.new(
    ['-i', GetoptLong::REQUIRED_ARGUMENT],
    ['--fam_list', GetoptLong::REQUIRED_ARGUMENT],
    ['--type', GetoptLong::REQUIRED_ARGUMENT],
  )


  opts.each do |opt, value|
    case opt
      when '-i'
        infile = value
      when '--fam_list'
        fam_list_file = value
      when '--type'
        types_included = value.split(',')
    end
  end


  #######################################################
  cdd_info = read_cdd_tbl(cdd_info, true)

  cdd_info.merge! read_kegg_tbl(cdd_info)

  fams = read_list(fam_list_file).keys if not fam_list_file.nil?

  output_result(cdd_info, fams, fam_list_file)
end


