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
proc newRedis(): RedisConn =
  var conn: RedisConn
  try:
    conn = newRedisConn(address = getEnv("REDIS_HOST", "localhost"))
  except RedisError as e:
    echo "Redis error: " & e.msg
    conn = nil
  return conn
var conn = newRedis()


proc reconnectRedisConn*() =
  try:
    if not isNil(conn):
      try:
        conn.close()
      except:
        discard  # Ignore quit errors
    conn = newRedis()
  except Exception as e:
    echo "Failed to reconnect to Redis: " & e.msg
    conn = nil


proc cacheGet*(keyformat: CacheKey, ident: string): (bool, JsonNode) =
  ## Get a value from the cache
  let key = ($keyformat).format(ident)

  try:
    if isNil(conn):
      reconnectRedisConn()
    if isNil(conn):
      return (false, nil)

    # First try to get the value directly
    let tmp = conn.command("GET", key).to(Option[string]).get("")
    if tmp != "":
      try:
        let parsed = parseJson(tmp)
        if parsed.kind != JObject:
          echo "Invalid JSON type for key: " & ident & " - expected JObject, got " & $parsed.kind
          return (false, nil)
        return (true, parsed)
      except:
        echo "Failed to parse JSON for key: " & ident & " - (" & decode(ident) & ") - " & getCurrentExceptionMsg()
        return (false, nil)
    else:
      # Key doesn't exist or is empty
      return (false, nil)
  except RedisError as e:
    echo "Redis error getting cache: " & e.msg
    reconnectRedisConn()
    return (false, nil)
  except:
    echo "Failed to get cache for key: " & ident & " - " & getCurrentExceptionMsg()
    reconnectRedisConn()
    return (false, nil)


proc cacheSet*(keyformat: CacheKey, key: string, value: JsonNode, expire = getEnv("EMAIL_CACHE_TIME", "157680000")) =
  ## Set a value in the cache
  # 2629800 seconds = 1 month
  try:
    if isNil(conn):
      reconnectRedisConn()
    if not isNil(conn):
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
  let expire = getEnv("ATTIO_API_RATE_LIMIT", "10")
  try:
    if isNil(conn):
      reconnectRedisConn()
    if not isNil(conn):
      discard conn.command("SET", ($keyformat).format(ident), "block", "EX", (if expire.len > 0: expire else: "10"))
  except:
    echo "Failed to set rate limit for key: " & ident & " - " & getCurrentExceptionMsg()


proc cacheClear*() =
  ## Clear the cache
  try:
    if isNil(conn):
      reconnectRedisConn()
    if not isNil(conn):
      discard conn.command("FLUSHALL")
  except:
    echo "Failed to clear cache" & " - " & getCurrentExceptionMsg()

