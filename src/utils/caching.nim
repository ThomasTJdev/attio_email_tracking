
when NimMajor >= 2:
  import std/envvars
else:
  import std/os

import
  std/[
    json,
    options,
    strutils
  ]

import
  ready


type
  CacheKey* = enum
    emailData = "attio:email:ident:$1"
    # emailData =
    # let data = %*{
    #   "email": email,
    #   "subject": subject,
    #   "epoch": toInt(epochTime()),
    #   "opens": 0,
    #   "clicks": {
    #     "link.com": 0,
    #     "link.com": 0
    #   }
    # }
    rateLimitOpen = "attio:ratelimit:open:ident:$1"
    rateLimitClick = "attio:ratelimit:click:ident:$1"
    companyDomainToCompanyID = "attio:company:domain:$1"
    companyDomainToDealID = "attio:company:deal:$1"


# Cache connection
let conn = newRedisConn(address = getEnv("REDIS_HOST", "localhost"))


proc cacheGet*(keyformat: CacheKey, ident: string): (bool, JsonNode) =
  ## Get a value from the cache
  let data = conn.command("GET", ($keyformat).format(ident)).to(Option[string]).get("")
  if data == "":
    return (false, nil)
  else:
    try:
      result = (true, parseJson(data))
    except:
      result = (false, nil)


proc cacheSet*(keyformat: CacheKey, key: string, value: JsonNode, expire = getEnv("EMAIL_CACHE_TIME", "157680000")) =
  ## Set a value in the cache
  # 2629800 seconds = 1 month
  discard conn.command("SET", ($keyformat).format(key), $value, "EX", expire)


proc cacheRateLimitBlock*(keyformat: CacheKey, ident: string): bool =
  ## Check if a key exists in the cache
  return conn.command("EXISTS", ($keyformat).format(ident)).to(Option[int]).get(0) == 1


proc cacheRateLimitSet*(keyformat: CacheKey, ident: string) =
  ## Set key which blocks further requests for a certain time
  discard conn.command("SET", ($keyformat).format(ident), "block", "EX", getEnv("ATTIO_API_RATE_LIMIT", "5"))


proc cacheClear*() =
  ## Clear the cache
  discard conn.command("FLUSHALL")

