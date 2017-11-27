#!/usr/bin/env ruby

$VERBOSE = false

class DeDup

  def initialize
    @inodes = {}
    @hashes = Hash.new { |h,k| h[k] = Array.new }
    @files = {}
  end

  def run_hash(files)
    rows = []
    i = 0
    # Split the file list into more managable chunks to avoid exceeding maximum command line argument length
    while i < files.size
      chunk = files.slice(i,10).map{|f| f.gsub(/"/, '\\"')} # get next chunk and escape double-quotes
      rows += `sha256sum "#{chunk.join('" "')}"`.split(/\n/)
      i += 10
    end
    rows
  end

  def get_files_info(files)
    puts "get_files_info(#{files.join(' ')})" if $VERBOSE
    files = files.select do |file|
      return false if File.symlink?(file)
      s = File.stat(file)
      File.file?(file) && s.size != 0 && !@hashes.include?(s.ino)
    end
    return {} if files.empty?
    # We are dealing with some very large files, so run external hash tool
    puts "sha256sum '#{files.join('\' \'')}'" if $VERBOSE
    run_hash(files).inject({}) do |hash,row|
      h, f = row.strip.split(/\s+/, 2)
      s = File.stat(f)
      puts "#{f} => #{h} (#{s.ino})" if $VERBOSE
      hash[f] = {hash: h, inode: s.ino, size: s.size}
      if @hashes.include?(h) && !@inodes.include?(s.ino)
        puts "Dup: #{f} #{@hashes[h].join(' ')}"
      end
      @inodes[s.ino] = f
      @hashes[h] << f
      hash
    end
  end

  def scan(paths)
    puts "scan(#{paths.join(' ')})" if $VERBOSE
    paths.each do |p|
      next if p.match(/\/\.\.?$/) || File.symlink?(p)
      if File.directory?(p)
        scan(Dir["#{p}/*", "#{p}/.*"])
        get_files_info(Dir["#{p}/*", "#{p}/.*"])
      end
    end
    nil
  end

  def run(args)
    args = Array(args)
    scan(args)
  end

end

DeDup.new.run(ARGV)
