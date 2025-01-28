---@meta

---@alias NotificationPosition 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left' | 'center-right' | 'center-left'
---@alias NotificationType 'info' | 'warning' | 'success' | 'error'
---@alias PlayerIdentifier 'username' | 'license' | 'license2' | 'fivem' | 'discord'
---@alias Source integer

---@class ErrorResult
---@field code string
---@field message string

---@class CharacterRegistration
---@field firstname string
---@field lastname string
---@field nationality string
---@field gender number
---@field birthdate string
---@field cid integer

---@class SubQueue : SubQueueConfig
---@field positions table<string, number> Player license to sub-queue position map.
---@field size number

---@class PlayerQueueData
---@field waitingSeconds number
---@field subQueueIndex number
---@field globalPos number

---@class Deferrals https://docs.fivem.net/docs/scripting-reference/events/list/playerConnecting/#deferring-connections
---@field defer fun() initialize deferrals for the current resource. Required to wait at least 1 tick before calling other deferrals methods.
---@field update fun(message: string) sends a progress message to the connecting client
---@field presentCard fun(card: unknown|string, cb?: fun(data: unknown, rawData: string)) send an adaptive card to the client https://learn.microsoft.com/en-us/adaptive-cards/authoring-cards/getting-started and capture user input via callback.
---@field done fun(failureReason?: string) finalizes deferrals. If failureReason is present, user will be refused connection and shown reason. Need to wait 1 tick after calling other deferral methods before calling done.

---@class Player
---@field Functions PlayerFunctions
---@field PlayerData PlayerData
---@field Offline boolean

---@class PlayerData : PlayerEntity
---@field jobs table<string, integer>
---@field gangs table<string, integer>
---@field source? Source present if player is online
---@field optin? boolean present if player is online

---@class PlayerFunctions
---@field UpdatePlayerData fun()
---@field SetJob fun(job: string, grade: integer): boolean
---@field SetGang fun(gang: string, grade: integer): boolean
---@field SetJobDuty fun(onDuty: boolean)
---@field SetPlayerData fun(key: string, val: any)
---@field SetMetaData fun(meta: string, val: any)
---@field GetMetaData fun(meta: string): any
---@field AddJobReputation fun(amount: number)
---@field AddMoney fun(moneytype: MoneyType, amount: number, reason?: string): boolean
---@field RemoveMoney fun(moneytype: MoneyType, amount: number, reason?: string): boolean
---@field SetMoney fun(moneytype: MoneyType, amount: number, reason?: string): boolean
---@field GetMoney fun(moneytype: MoneyType): boolean | number
---@field SetCreditCard fun(cardNumber: number)
---@field Save fun()
---@field Logout fun()

---@class GroupData
---@field label string

---@class JobData : GroupData
---@field type? string
---@field defaultDuty boolean
---@field offDutyPay boolean

---@class GangData : GroupData

---@class GradeData
---@field name string
---@field isboss? boolean
---@field bankAuth? boolean

---@class JobGradeData : GradeData
---@field payment number

---@class GangGradeData : GradeData

---@class Job : JobData
---@field grades table<integer, JobGradeData>

---@class Gang : GangData
---@field grades table<integer, GangGradeData>

---@class StorageFunctions
---@field insertBan fun(request: InsertBanRequest)
---@field fetchBan fun(request: GetBanRequest): BanEntity?
---@field deleteBan fun(request: GetBanRequest)
---@field upsertPlayerEntity fun(request: UpsertPlayerRequest)
---@field fetchPlayerSkin fun(citizenId: string): PlayerSkin?
---@field fetchPlayerEntity fun(citizenId: string): PlayerEntity?
---@field searchPlayerEntities fun(filters: table<string, any>): Player[]
---@field fetchAllPlayerEntities fun(license2: string, license?: string): PlayerEntity[]
---@field deletePlayer fun(citizenId: string): boolean success
---@field fetchIsUnique fun(type: UniqueIdType, value: string|number): boolean
---@field addPlayerToJob fun(citizenid: string, group: string, grade: integer)
---@field addPlayerToGang fun(citizenid: string, group: string, grade: integer)
---@field fetchPlayerGroups fun(citizenid: string): table<string, integer>, table<string, integer> jobs, gangs
---@field removePlayerFromJob fun(citizenid: string, group: string)
---@field removePlayerFromGang fun(citizenid: string, group: string)
---@field sendPlayerDataUpdates fun()
---@field forcePlayerDataUpdate fun(citizenid: string)
---@field addPlayerDataUpdate fun(citizenid: string, key: string | string[], value: any)

---@class InsertBanRequest
---@field name string
---@field license? string
---@field discordId? string
---@field ip? string
---@field reason string
---@field bannedBy string
---@field expiration integer epoch second that the ban will expire

---@class GetBanRequest
---@field license? string
---@field discordId? string
---@field ip? string

---@class BanEntity
---@field expire integer epoch second that the ban will expire
---@field reason string

---@class UpsertPlayerRequest
---@field playerEntity PlayerEntity
---@field position vector3

---@class PlayerEntity
---@field userId? integer
---@field citizenid string
---@field license string
---@field name string
---@field money Money
---@field charinfo PlayerCharInfo
---@field job? PlayerJob
---@field gang? PlayerGang
---@field position vector4
---@field metadata PlayerMetadata
---@field cid integer
---@field lastLoggedOut integer
---@field items table deprecated

---@class PlayerEntityDatabase : PlayerEntity
---@field charinfo string
---@field money string
---@field job? string
---@field gang? string
---@field position string
---@field metadata string
---@field lastLoggedOutUnix integer

---@class PlayerCharInfo
---@field firstname string
---@field lastname string
---@field birthdate string
---@field nationality string
---@field cid integer
---@field gender integer
---@field backstory string
---@field phone string
---@field account string
---@field card number

---@class PlayerMetadata
---@field health number
---@field armor number
---@field hunger number
---@field thirst number
---@field stress number
---@field isdead boolean
---@field inlaststand boolean
---@field ishandcuffed boolean
---@field tracker boolean
---@field injail number time in minutes
---@field jailitems table TODO: expand
---@field status table TODO: expand
---@field phone {background: any, profilepicture: any} TODO: figure out more specific types
---@field bloodtype BloodType
---@field dealerrep number
---@field craftingrep number
---@field attachmentcraftingrep number
---@field currentapartment? integer apartmentId
---@field jobrep {tow: number, trucker: number, taxi: number, hotdog: number}
---@field callsign string
---@field fingerprint string
---@field walletid string
---@field criminalrecord {hasRecord: boolean, date?: table} TODO: date is os.date(), create better type than table
---@field licences {id: boolean, driver: boolean, weapon: boolean}
---@field inside {house?: any, apartment: {apartmentType?: any, apartmentId?: integer}} TODO: expand
---@field phonedata {SerialNumber: string, InstalledApps: table} TODO: expand
---@field [string] any

---@class PlayerJob
---@field name string
---@field label string
---@field payment number
---@field type? string
---@field onduty boolean
---@field isboss boolean
---@field grade {name: string, level: number}

---@class PlayerGang
---@field name string
---@field label string
---@field isboss boolean
---@field grade {name: string, level: number}

---@class PlayerSkin
---@field citizenid string
---@field model string
---@field skin string
---@field active integer

---@class Item
---@field name string
---@field label string
---@field weight number
---@field type string
---@field ammotype? string
---@field image string
---@field unique boolean
---@field useable boolean
---@field shouldClose? boolean
---@field combineable? false|table
---@field description string

---@class Locale
---@field fallback? Locale
---@field warnOnMissing boolean
---@field phrases table
---@field currentLocale string
---@field new fun(_: Locale, opts: table<string, any>): Locale
---@field extend fun(self: Locale, phrases: table<string, string>, prefix: string?)
---@field clear fun(self: Locale)
---@field replace fun(self: Locale, phrases: table<string, any>)
---@field locale fun(self: Locale, newLocale: string): string
---@field t fun(self: Locale, key: string, subs: table<string, any>?): string
---@field has fun(self: Locale, key: string): boolean
---@field delete fun(self: Locale, phraseTarget: string | table, prefix: string)

---@class Vehicle
---@field name string
---@field brand string
---@field model string
---@field price number
---@field category string
---@field hash string | integer actually just an integer but string is required for types to align when using `asbo` for example

---@class Weapon
---@field name string
---@field label string
---@field weapontype string
---@field ammotype? string
---@field damagereason string
