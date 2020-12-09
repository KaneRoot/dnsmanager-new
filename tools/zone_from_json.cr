require "./src/storage.cr"


alias DSZ = DNSManager::Storage::Zone

zone = DSZ.from_json File.read(ARGV[0])
pp! zone
