require 'net/ftp'

# Downloads tarball at the given URL if a local copy does not exist, or if the
# local copy is older than at the given URL, or if the local copy is corrupt.
def download(url)
  file = File.basename(url)
  # Resume an interrupted download or fetch the file for the first time. If
  # the file on the server is newer, then it is downloaded from start.
  sh "wget -Nc #{url}"
  # If the local copy is already fully retrieved, then the previous command
  # ignores the timestamp. So we check with the server again if the file on
  # the server is newer and if so download the new copy.
  sh "wget -N #{url}"

  # Immediately download md5 and verify the tarball. Re-download tarball if
  # corrupt; extract otherwise.
  sh "wget #{url}.md5 && md5sum -c #{file}.md5" do |matched, _|
    if !matched
      sh "rm #{file} #{file}.md5"; download(url)
    else
      sh "tar xvf #{file}"
    end
  end
end

# Connects to NCBI's FTP server, gets the URL of all database volumes and
# returns them grouped by database name:
#
#     {'nr' => ['ftp://...', ...], 'nt' => [...], ...}
#
def databases
  host, dir = 'ftp.ncbi.nlm.nih.gov', 'blast/db'
  usr, pswd = 'anonymous', ENV['email']

  Net::FTP.open(host, usr, pswd) do |con|
    con.passive = true
    con.nlst(dir).
      map { |file| File.join(host, file) }.
      select { |file| file.match(/\.tar\.gz$/) }.
      group_by { |file| File.basename(file).split('.')[0] }
  end
end

# Create user-facing task for each database to drive the download of its
# volumes in parallel.
databases.each do |name, files|
  multitask(name => files.map { |file| task(file) { download(file) } })
end

# Taxonomy database is different from sequence databases.
task :taxdump do
  download 'ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz'
end

# List name of all databases that can be downloaded if executed without
# any arguments.
task :default do
  puts databases.keys.push('taxdump').join(', ')
end
