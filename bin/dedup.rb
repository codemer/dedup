#!/usr/bin/env ruby

$VERBOSE = false

class DeDup

  def initialize
    @inodes = {}
    @hashes = {}
    @files = {}
    @save_size = 0
    @run = false
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
      s = File.lstat(file)
      # Only include files, and ignore symlinks
      (s.mode & 0100000) != 0 && (s.mode & 0020000) == 0 && s.size != 0 && !@hashes.include?(s.ino)
    end
    return {} if files.empty? # no actionable files in current directory
    # We are dealing with some very large files, so run external hash tool
    puts "sha256sum '#{files.join('\' \'')}'" if $VERBOSE
    run_hash(files).inject({}) do |hash,row|
      h, f = row.strip.split(/\s+/, 2)
      unless File.writable?(File.dirname(f))
        STDERR.puts "Skipping file in unwritable directory: #{f}"
        next hash
      end
      s = File.stat(f)
      if s.uid != Process.uid
        STDERR.puts "Skipping file not owned by current user: #{f} (uid=#{s.uid})"
        next hash
      end
      puts "#{f} => #{h} (#{s.ino})" if $VERBOSE
      hash[f] = {hash: h, inode: s.ino, size: s.size, dev: s.dev, mode: s.mode}
      if @hashes.include?(h) && !@inodes.include?(s.ino)
        puts "Dupe: #{f} <==> #{@hashes[h]} (#{(s.size/1024).to_i}KB)"
        dupe = @files[@hashes[h]]
        STDOUT.flush
        raise "Files on different devices!!! Unsupported" if s.dev != dupe[:dev]
        if s.mode == dupe[:mode]
          @save_size += s.size
          if @run
            begin
              File.chmod(0777, f)
              File.unlink(f)
              File.link(@hashes[h], f)
            rescue StandardError => e
              STDERR.puts "Unable to linkify file #{f}: #{e.message}"
            end
          end
        else
          STDERR.puts "Skipping: modes don't match: #{f} (#{sprintf('%o',s.mode&0777)} != #{sprintf('%o',dupe[:mode]&0777)})"
        end
      end
      @inodes[s.ino] = f
      @files[f] = hash[f]
      @hashes[h] = f unless @hashes.include?(h)
      hash
    end
  end

  def scan(paths)
    puts "scan(#{paths.join(' ')})" if $VERBOSE
    paths.each do |p|
      next if p.match(/\/\.\.?$/) || File.symlink?(p)
      if File.directory?(p)
        scan(Dir["#{p}/*", "#{p}/.*"].sort)
        get_files_info(Dir["#{p}/*", "#{p}/.*"].sort)
      end
    end
    nil
  end

  def help
    puts "Usage: #{$0} [-h|--help|--run] <dir1..dirn>"
    exit
  end

  def run(args)
    args = Array(args)
    help if args.empty?
    while args.first.match(/^-/)
      arg = args.shift
      @run = true if arg == '--run'
      help if arg == '-h' || arg == '--help'
    end
    scan(args)
    puts "Will save #{(@save_size/1024).to_i}KB"
  end

end

DeDup.new.run(ARGV)
