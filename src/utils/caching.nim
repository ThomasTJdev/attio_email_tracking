
when NimMajor >= 2:
  import std/envvars
else:
  import std/os

import
  std/[
    base64,
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
var conn = newRedisConn(address = getEnv("REDIS_HOST", "localhost"))


template reconnectRedisConn*() =
  ## Reconnect to the Redis connection
  conn.close()
  conn = newRedisConn(address = getEnv("REDIS_HOST", "localhost"))


proc cacheGet*(keyformat: CacheKey, ident: string): (bool, JsonNode) =
  ## Get a value from the cache
  let key = ($keyformat).format(ident)

  try:
    if conn.command("EXISTS", key).to(int) != 1:
      return (false, nil)
  except:
    echo "Failed to check cache for key #1: " & ident & " - " & getCurrentExceptionMsg()
    if getCurrentExceptionMsg().contains("connection is in a broken state"):
      reconnectRedisConn()
    return (false, nil)

  var tmp: string
  try:
    tmp = conn.command("GET", key).to(Option[string]).get("")
  except:
    echo "Failed to get cache for key #2: " & ident & " - " & getCurrentExceptionMsg()
    if getCurrentExceptionMsg().contains("connection is in a broken state"):
      reconnectRedisConn()
    return (false, nil)

  if tmp == "":
    return (false, nil)

  try:
    result = (true, parseJson(tmp))
  except:
    echo "Failed to get cache for key #3: " & ident & " - (" & decode(ident) & ") - " & getCurrentExceptionMsg()
    result = (false, nil)


proc cacheSet*(keyformat: CacheKey, key: string, value: JsonNode, expire = getEnv("EMAIL_CACHE_TIME", "157680000")) =
  ## Set a value in the cache
  # 2629800 seconds = 1 month
  try:
    discard conn.command("SET", ($keyformat).format(key), $value, "EX", expire)
  except:
    echo "Failed to set cache for key: " & key & " - (" & decode(key) & ") - " & getCurrentExceptionMsg()


proc cacheRateLimitBlock*(keyformat: CacheKey, ident: string): bool =
  ## Check if a key exists in the cache
  let key = ($keyformat).format(ident)

  try:
    if conn.command("EXISTS", key).to(int) != 1:
      return false
    else:
      return true
  except:
    echo "Failed to check rate limit for key #1: " & ident & " - " & getCurrentExceptionMsg()
    return false


proc cacheRateLimitSet*(keyformat: CacheKey, ident: string) =
  ## Set key which blocks further requests for a certain time
  let expire = getEnv("ATTIO_API_RATE_LIMIT", "5")
  try:
    discard conn.command("SET", ($keyformat).format(ident), "block", "EX", (if expire.len > 0: expire else: "5"))
  except:
    echo "Failed to set rate limit for key: " & ident & " - " & getCurrentExceptionMsg()


proc cacheClear*() =
  ## Clear the cache
  try:
    discard conn.command("FLUSHALL")
  except:
    echo "Failed to clear cache" & " - " & getCurrentExceptionMsg()

