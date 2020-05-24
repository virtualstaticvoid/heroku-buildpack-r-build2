#!/usr/bin/env ruby

require 'open3'

def find_depend_libs(binary)
  cmd = "ldd #{binary} | awk '{print $3}' | sort -u"
  data = ""
  Open3.popen3(cmd, :chdir=>"/") do |i, o, e, t|
    data = o.read.chomp
    t.value
  end
  data.split("\n")
      .reject {|s| s == "" }
      .reject {|s| s =~ /^\/app/ }
      .select {|s| File.exists?(s) }
      .collect {|f| [f, File.basename(f)] }
end

def copy_depend_libs(path, binary)
  find_depend_libs(binary).each do |src, dest|
    target = File.join(path, dest)
    next if File.exists?(target)
    print "#{src} => #{target} "
    copy_binary_file src, target
    if target =~ /\.so/ && target !~ /\.so$/
      Dir.chdir(File.dirname(target)) do
        basename = File.basename(target)
        symlinkname = basename.sub(/\.so.*/, ".so")
        File.symlink(basename, symlinkname) unless File.exists?(symlinkname)
      end
    end
    print "[OK]\n"
    copy_depend_libs path, src
  end
end

def copy_binary_file(src, target)
  File.open(src, 'rb') do |f|
    File.open(target, 'wb') do |g|
      g.chmod(0777) # executable
      g.write(f.read)
    end
  end
end

# destination for copied libs
dest_path = "/app/R/lib/R/lib"

# resolve R binary dependencies
ENV['LD_LIBRARY_PATH'] = "/app/tcltk/lib:/app/R/lib/R/lib"

# R binary
copy_depend_libs(dest_path, "/app/R/lib/R/bin/exec/R")

# all related SO files
Dir.glob("/app/R/lib/**/*.so").each do |binary|
  copy_depend_libs(dest_path, binary)
end
