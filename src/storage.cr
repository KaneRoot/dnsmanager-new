require "json"
require "uuid"
require "uuid/json"
require "baguette-crystal-base"

require "dodb"

class DNSManager::Storage
	getter user_data         : DODB::CachedDataBase(UserData)
	getter user_data_by_uid  : DODB::Index(UserData)

	getter zones             : DODB::CachedDataBase(Zone)
	getter zones_by_domain   : DODB::Index(Zone)

	def initialize(@root : String, reindex : Bool = false)
		@user_data         = DODB::CachedDataBase(UserData).new "#{@root}/user-data"
		@user_data_by_uid  = @user_data.new_index "uid", &.uid.to_s
		@zones             = DODB::CachedDataBase(Zone).new "#{@root}/zones"
		@zones_by_domain   = @zones.new_index "domain", &.domain

		Baguette::Log.info "storage initialized"

		if reindex
			Baguette::Log.debug "Reindexing user data..."
			@user_data.reindex_everything!
			Baguette::Log.debug "Reindexing zones..."
			@zones.reindex_everything!
			Baguette::Log.debug "Reindexed!"
		end
	end

	def get_user_data(uid : Int32)
		user_data_by_uid.get uid.to_s
	rescue e : DODB::MissingEntry
		entry = UserData.new uid
		entry
	end

	def get_user_data(user : ::AuthD::User::Public)
		get_user_data user.uid
	end

	def update_user_data(user_data : UserData)
		user_data_by_uid.update_or_create user_data.uid.to_s, user_data
	end

	def new_domain(user_id : Int32, zone : Zone)
		user_data = user_data_by_uid.get? user_id.to_s
		if user_data
			# store the new zone
			@zones << zone

			# update user data only after ensuring this zone isn't already existing
			user_data.domains << zone.domain
			update_user_data user_data
		else
			Baguette::Log.error "trying to add zone #{zone.domain} to unknown user #{user_id}"
		end
	rescue e
		Baguette::Log.error "trying to add zone #{zone.domain} #{e}"
	end
end

require "./storage/*"
