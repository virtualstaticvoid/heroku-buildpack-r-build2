#!/usr/bin/env ruby

require 'open3'

def find_dependent_pkgs(package)
  cmd = "apt-cache depends #{package}"

  output = ""
  res = nil
  Open3.popen2e(cmd, :chdir=>"/") do |stdin, stdout_stderr, wait_thr|
    output = stdout_stderr.read.chomp
    res = wait_thr.value
  end

  raise StandardError.new("Failed to find dependent packages for '#{package}'. #{output}") if res&.exitstatus != 0

  output.split("\n")
      .reject {|s| s == "" }
      .select {|s| s =~ /Depends: .*/ }
      .reject {|s| s.include?("<") }
      .collect {|s| s.split(" ").last }
end

R_VERSION = ARGV[0] || "4.0.0"

dev = find_dependent_pkgs "r-base-dev=#{R_VERSION}*"
dev.reject! {|s| s == "r-base-core" }

base = find_dependent_pkgs "r-base-core=#{R_VERSION}*"

puts (dev + base).uniq.sort.join(" ")
