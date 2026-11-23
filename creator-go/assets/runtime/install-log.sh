#!/bin/sh
# The installed first-boot console needs a short summary. The installer error
# dialog can scroll, so keep every line from its available logs.
LC_ALL=C
export LC_ALL
if [ "${1:-}" = --stdin ]; then
 awk '
  {
   gsub(/[[:cntrl:]]/, " ")
   if (tolower($0) ~ /password|passwd|chpasswd|credential|secret|token|authorization|:\/\/[^ \/]+@/) next
   sub(/^[A-Z][a-z][a-z] +[0-9]+ [0-9:]+ /, "")
   if (!NF) next
   important = (tolower($0) ~ /error|fail|cannot|could not|unable|denied|read.only|no space|not found|mismatch|stopped/)
   if (length($0) > 104) $0 = substr($0,1,45) " ... " substr($0,length($0)-53)
   entry[++n]=$0
   if (important) last_error=n
  }
  END {
   first = n>4 ? n-3 : 1
   if (last_error && last_error<first) { print entry[last_error]; first++ }
   for (i=first; i<=n; i++) print entry[i]
   if (!n) print "No installer log entries available yet."
  }
 '
 exit $?
fi

# Use awk filenames to retain provenance. BusyBox syslogd rotates to syslog.0.
set --
for file in /var/log/syslog.0 /var/log/syslog /target/var/log/apt/term.log; do
 [ ! -r "$file" ] || set -- "$@" "$file"
done
if [ "$#" -eq 0 ]; then
 echo 'No installer logs are available yet.'
 exit 0
fi
awk '
 function safe(line) {
  gsub(/[[:cntrl:]]/, " ", line)
  if (tolower(line) ~ /password|passwd|chpasswd|credential|secret|token|authorization|:\/\/[^ \/]+@/) return "[credential line hidden]"
  return line
 }
 mode=="summary" {
  line=safe($0)
  if (tolower(line) ~ /(^|[[:space:]])(e: |err:|dpkg: error)|unmet dependencies|depends:|failed to fetch|unable to locate|no installation candidate|no space left|input\/output error|hash sum mismatch/) {
   if (line != previous) errors[count++ % 3]=line
   previous=line
  }
  next
 }
 !heading {
  if (count) {
   print "Package or disk errors:"
   for (i=count>3?count-3:0; i<count; i++) print errors[i % 3]
   print ""
  }
  print "Full installer log (scroll to read)"
  heading=1
 }
 FNR==1 { print ""; print FILENAME }
 { print safe($0) }
 END { if (!heading) print "No installer log entries available yet." }
 ' mode=summary "$@" mode=full "$@"
