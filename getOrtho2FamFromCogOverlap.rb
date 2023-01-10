#! /usr/bin/env ruby


################################################
require 'getoptlong'

require 'Dir'
require 'util'


################################################
$SORTED_TYPES = [:TIGRFAM, :COG, :pfam, :PRK, :cd, :kegg]


################################################
infiles = Array.new
indir = nil
suffix = nil
prop_min = 0.5

ortho2cdd = Hash.new{|h,k|h[k]={}}
ortho2prop = Hash.new{|h,k|h[k]={}}


################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['--prop_min', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '-i'
      infiles << value.split(',')
    when '--indir'
      indir = value
    when '--suffix'
      suffix = value
    when '--prop_min'
      prop_min = value.to_f
  end
end


infiles = read_infiles(indir, suffix) unless indir.nil?
infiles.flatten!


################################################
infiles.each do |infile|
  c = getCorename(infile, true)
  in_fh = File.open(infile, 'r')
  in_fh.each_line do |line|
    #OG0000003	5990	276	cd06261,276
    line.chomp!
    line_arr = line.split("\t")
    next if line_arr.size <= 3
    fam = line_arr[0]
    no_total, no_hit = line_arr[1, 2].map(&:to_i)
    best_cdd_str = line_arr[3]
    best_cdd, no_best_cdd = best_cdd_str.split(',')
    no_best_cdd = no_best_cdd.to_i
    prop = no_best_cdd/no_total.to_f
    if prop >= prop_min
      ortho2cdd[fam][c.to_sym] = best_cdd
      ortho2prop[fam][c.to_sym] = prop.round(2)
    end
    #puts no_best_cdd
  end
  in_fh.close
end


################################################
ortho2cdd.each_pair do |fam, v1|
  a = $SORTED_TYPES.map do |i|
    v1.include?(i) ? [v1[i], ortho2prop[fam][i]].join('|') : nil
  end
  puts [fam, a].flatten.join("\t")
end


