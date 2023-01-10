#! /usr/bin/env ruby


#######################################################
$DIR = File.dirname($0)
$: << $DIR


#######################################################
require 'getoptlong'

require 'chang_yong'
require 'createCddSqliteDb'


#######################################################
$TYPES = %w[TIGRFAM COG pfam PRK cd KEGG]


#######################################################
infile = nil
fam_list_file = nil
types_included = Array.new

fams = Array.new
cdd_info = Hash.new{|h,k|h[k]={}}


#######################################################
def read_ortho2func(infile, cdd_info, types_included)
  ortho2func = Hash.new{|h,k|h[k]={}}
  in_fh = File.open(infile, 'r')
  in_fh.each_line do |line|
    line.chomp!
    line_arr = line.split("\t")
    fam = line_arr[0]
    strs = line_arr[1, line_arr.size-1]
    strs.each_with_index do |str, index|
      output_strs = Array.new
      type = $TYPES[index]
      next unless types_included.include?(type) if not types_included.empty?
      cdd, prop = str.split('|')
      prop = prop.to_f
      output_strs = [%w[name gene prot].map{|i|cdd_info[cdd][i]}, prop].flatten
      ortho2func[fam][type] = output_strs
    end
  end
  in_fh.close
  return(ortho2func)
end


def output_result(ortho2func, fams, fam_list_file)
  ortho2func.each_pair do |ortho, v|
    next unless fams.include?(ortho) if not fam_list_file.nil?
    outputs = v.sort_by{|a,b|$TYPES.index(a)}.map{|a,b|b}
    puts [ortho, outputs].join("\t")
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

  ortho2func = read_ortho2func(infile, cdd_info, types_included)

  fams = read_list(fam_list_file).keys if not fam_list_file.nil?

  output_result(ortho2func, fams, fam_list_file)
end


