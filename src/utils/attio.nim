
import
  std/[
    envvars,
    json,
    httpcore,
    httpclient,
    strutils,
    times
  ]

import
  ./caching

type
  MailAction* = enum
    open
    click


template attioApiClient*(envAttioBearer: string): HttpClient =
  ## Create a new HTTP client with the required headers
  let client = newHttpClient()
  client.headers = newHttpHeaders({
    "accept": "application/json",
    "authorization": "Bearer " & envAttioBearer,
    "content-type": "application/json"
  })
  client


proc attioApiSend*(httpMethod: HttpMethod, path: string, body: JsonNode): tuple[success: bool, body: string] =
  ## Send a request to the Attio API
  let client = attioApiClient(getEnv("ATTIO_API_KEY", "attio"))
  try:
    let response = client.request(path, httpMethod = httpMethod, body = $body)
    if code(response).is2xx():
      return (true, response.body)
    else:
      echo("attioApiSend(): Failed to send request to Attio API: " & path & " - got response: " & $response.status & " - " & response.body)
      return (false, response.body)
  finally:
    client.close()


proc attioApiPutPerson(email: string, body: JsonNode): bool =
  ## Update a person in Attio
  let path = "https://api.attio.com/v2/objects/people/records?matching_attribute=email_addresses"
  let (success, body) = attioApiSend(httpMethod = HttpPut, path = path, body = body)
  return success


proc attioApiPutCompany(domain: string, body: JsonNode): bool =
  ## Update a company in Attio
  let path = "https://api.attio.com/v2/objects/companies/records?matching_attribute=domains"
  let (success, body) = attioApiSend(httpMethod = HttpPut, path = path, body = body)
  return success


proc attioApiGetCompanyUUID(domain: string): string =
  ## Get the company ID from Attio

  let (cacheSucces, cachedJson) = cacheGet(CacheKey.companyDomainToCompanyID, domain)
  if cacheSucces:
    return cachedJson["uuid"].getStr()

  let path = "https://api.attio.com/v2/objects/companies/records?matching_attribute=domains"
  let (success, body) = attioApiSend(httpMethod = HttpPut, path = path, body = %*{
    "data": {
      "values": {
        "domains": @[domain],
      }
    }
  })
  if success:
    let uuid = parseJson(body)["data"]["id"]["record_id"].getStr()
    cacheSet(CacheKey.companyDomainToCompanyID, domain, %*{"uuid": uuid}, expire = "86400")
  else:
    return ""


proc attioApiGetDealsUUID(domain, companyUUID: string): string =
  ## Get the deal ID from Attio

  let (cacheSucces, cachedJson) = cacheGet(CacheKey.companyDomainToDealID, companyUUID)
  if cacheSucces:
    return cachedJson["uuid"].getStr()

  let path = "https://api.attio.com/v2/objects/deals/records/query"
  let (success, body) = attioApiSend(httpMethod = HttpPost, path = path, body = %*{
      "filter": {
        "associated_company": {
          "target_object": "companies",
          "target_record_id": companyUUID
        }
      },
      "limit": 1
    })

  if success:
    var uuid: string
    try:
      uuid = parseJson(body)["data"][0]["id"]["record_id"].getStr()
    except:
      return ""
    cacheSet(CacheKey.companyDomainToDealID, domain, %*{"uuid": uuid}, expire = "86400")
    return uuid
  else:
    return ""


proc attioApiPatchDeals(dealRecordId: string, body: JsonNode): bool =
  ## Update a company in Attio
  let path = "https://api.attio.com/v2/objects/deals/records/" & dealRecordId
  let (success, body) = attioApiSend(httpMethod = HttpPatch, path = path, body = body)
  return success


proc emailAction*(parsed: JsonNode, mailAction: MailAction, userAgent = "", clickedUrl = "") =
  ## Handle an email open event
  ## 1. Get email data from cache and parse as JSON
  ## 2. Check if the rate limit is open based on parsed["email"]
  ## 3. If rate limit is open, update the person in Attio with env
  ##    var "ATTIO_PEOPLE_SLUG_EMAIL_OPEN" and a text with:
  ##    <email> has opened the email the email: <subject>

  #
  # Parse the email data
  #
  let
    email = parsed["email"].getStr()
    domain = email.split("@")[1]
    subject = parsed["subject"].getStr()


  #
  # Person object
  #
  # => The environmental variable is assumed to always be set on people,
  #    so it needs to be set to "false" to disable tracking.
  if (
    getEnv("ATTIO_TRACKER_PEOPLE_ON").toLowerAscii() != "false" and
    not cacheRateLimitBlock(CacheKey.rateLimitOpen, email)
  ):
    when defined(dev):
      echo("Person tracking is enabled")

    let slug = (
      if mailAction == MailAction.open:
        getEnv("ATTIO_PEOPLE_SLUG_EMAIL_OPEN", "email_opened")
      else:
        getEnv("ATTIO_PEOPLE_SLUG_EMAIL_CLICK", "email_clicked")
    )

    let
      info = (
        if mailAction == MailAction.open:
          subject & " - (" & now().utc.format("YYYY-MM-dd HH:mm 'UTC'") & ")" #& " - [" & userAgent & "]"
        else:
          subject & " - URL: " & clickedUrl & " - (" & now().utc.format("YYYY-MM-dd HH:mm 'UTC'") & ")" #& " - [" & userAgent & "]"
      )

    let body = %*{
      "data": {
        "values": {
          "email_addresses": @[email],
          slug: info
        }
      }
    }

    discard attioApiPutPerson(email, body)
    cacheRateLimitSet(CacheKey.rateLimitOpen, email)


  #
  # Company object
  #
  # => The environmental variable is assumed to always be off on companies,
  #    so it needs to be set to "true" to enable tracking.
  if (
    getEnv("ATTIO_TRACKER_COMPANY_ON").toLowerAscii() == "true" and
    not cacheRateLimitBlock(CacheKey.rateLimitOpen, domain)
  ):
    when defined(dev):
      echo("Company tracking is enabled")

    let slug = (
      if mailAction == MailAction.open:
        getEnv("ATTIO_COMPANY_SLUG_EMAIL_OPEN", "email_opened")
      else:
        getEnv("ATTIO_COMPANY_SLUG_EMAIL_CLICK", "email_clicked")
    )

    let
      info = (
        if mailAction == MailAction.open:
          email & " opened: " & subject & " - (" & now().utc.format("YYYY-MM-dd HH:mm 'UTC'") & ")" 
        else:
          email & " clicked: " & subject & " - URL: " & clickedUrl & " - (" & now().utc.format("YYYY-MM-dd HH:mm 'UTC'") & ")" 
      )

    let body = %*{
      "data": {
        "values": {
          "domains": @[domain],
          slug: info
        }
      }
    }

    discard attioApiPutCompany(domain, body)
    cacheRateLimitSet(CacheKey.rateLimitOpen, domain)


  #
  # Deal slug email open
  #
  # => The environmental variable is assumed to always be off on deals,
  #    so it needs to be set to "true" to enable tracking.
  if (
    getEnv("ATTIO_TRACKER_DEAL_ON").toLowerAscii() == "true" and
    not cacheRateLimitBlock(CacheKey.rateLimitOpen, "deal-" & domain)
  ):
    when defined(dev):
      echo("Deal tracking is enabled")

    let slug = (
      if mailAction == MailAction.open:
        getEnv("ATTIO_DEAL_SLUG_EMAIL_OPEN", "email_opened")
      else:
        getEnv("ATTIO_DEAL_SLUG_EMAIL_CLICK", "email_clicked")
    )

    let
      info = (
        if mailAction == MailAction.open:
          email & " opened: " & subject & " - (" & now().utc.format("YYYY-MM-dd HH:mm 'UTC'") & ")"
        else:
          email & " clicked: " & subject & " - URL: " & clickedUrl & " - (" & now().utc.format("YYYY-MM-dd HH:mm 'UTC'") & ")" 
      )

    let associatedCompany = attioApiGetCompanyUUID(domain)
    if associatedCompany == "":
      return
    let dealRecordId = attioApiGetDealsUUID(domain, associatedCompany)
    if dealRecordId == "":
      when defined(dev):
        echo("No deal found for company: " & associatedCompany)
      return

    let body = %*{
      "data": {
        "values": {
          slug: info
        }
      }
    }

    discard attioApiPatchDeals(dealRecordId, body)
    cacheRateLimitSet(CacheKey.rateLimitOpen, associatedCompany)



