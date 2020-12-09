require "./src/storage.cr"

alias DSZ = DNSManager::Storage::Zone

storage = DNSManager::Storage.new "STORAGE"

user_data = DNSManager::Storage::UserData.new 1004
storage.user_data << user_data rescue nil

zone = DSZ.new "test.my-domain.com"

a_record    = DSZ::A.new    "www",  600.to_u32, "127.0.0.1"
aaaa_record = DSZ::AAAA.new "www",  600.to_u32, "::1"
mx_record   = DSZ::MX.new   "mail", 600.to_u32, "127.0.0.1", 5.to_u32

zone.resources << a_record
zone.resources << aaaa_record
zone.resources << mx_record

storage.new_domain 1004, zone

pp! storage.user_data
puts "Zones !!!"
pp! storage.zones
storage.zones.to_a.each do |z|
	pp! z
end

