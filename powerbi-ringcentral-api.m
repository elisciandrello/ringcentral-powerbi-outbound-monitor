/*
	**************************
	RINGCENTRAL API FLOW
	CALL LOG API PULL
	**************************
*/


let
    Query1 = let
    
    /* Start of RingCentral Restful API Password Flow Authentication - registers and retrieves the access tokens storing them in a dataset */
    /* Available Auth Flows on RingCentral Developers Application: No Auth Code, Non Implicit, Password Authentication Enabled, Refresh Token Enabled */
    
    ringcentralUrl = "https://platform.ringcentral.com/restapi/oauth/token",
    ringcentralKey = <<YOUR RINGCENTRAL APP CLIENT ID>>,
    ringcentralSecret = <<YOUR RINGCENTRAL APP CLIENT SECRET>>,
    ringcentralCombined = Text.Combine({ringcentralKey, ringcentralSecret}, ":"),

    ringcentralA1 = Text.ToBinary(ringcentralCombined),
    ringcentralA2 = Binary.ToText(ringcentralA1, BinaryEncoding.Base64),
    AuthResult = Text.Combine({"Basic", ringcentralA2}, " "),

    ringcentralUser = <<YOUR USERNAME>>,
    ringcentralPassword = <<YOUR PASSWORD, SPECIAL CHARACTERS MUST BE CONVERTED TO WEB HEX>>,

    apiquery = "grant_type=password&username=" & ringcentralUser & "&password=" & ringCentralPassword & "&extension=<<YOUR EXTENSION>>&undefined=undefined",

    contents = Text.ToBinary(apiquery),

    options = [
        Headers = [
            Authorization = AuthResult,
            #"Content-Type" = "application/x-www-form-urlencoded;charset=UTF-8",
            #"Accept" = "application/json"
        ],
        Content = Text.ToBinary(apiquery)

    ],

    result = Web.Contents(ringcentralUrl, options),
    results = Json.Document(result),

    ringcentralAccessToken = results[access_token],
    ringcentralRefreshToken = results[refresh_token],

    LocalTemp = DateTime.LocalNow(),
    DateTemp = DateTime.Date(LocalTemp),
    callLogToday = Date.ToText(DateTemp, "yyyy-MM-dd"),

    /* End of Password Flow Authentication - Beginning of pulling call records */
    
    ringMainUrl = "https://platform.ringcentral.com/restapi/v1.0/account/~/call-log?view=Detailed&direction=Outbound&showBlocked=true&withRecording=false&dateFrom=" & callLogToday & "T00:00:01.000Z&dateTo=" & callLogToday & "T23:59:59.999Z&page=1&perPage=1000",
    callrecordsAuth = Text.Combine({"Bearer", ringcentralAccessToken}, " "),
    callrecordsHeaders = [
        Headers = [
            Authorization = callrecordsAuth,
            #"Content-Type" = "application/x-www-form-urlencoded",
            #"Accept" = "application/json"
        ]
        
    ],



    /* Pull JSON Call-Log from RingCentral API Server and start drill down/table process */

    callrecordsResultPull = Web.Contents(ringMainUrl, callrecordsHeaders),
    callrecordsResults = Json.Document(callrecordsResultPull),

    /* Start of Drill Down/Table Process */
    records = callrecordsResults[records]

in
    callrecordsResults,
    records = Query1[records],
    #"Converted to Table" = Table.FromList(records, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"uri", "id", "sessionId", "startTime", "duration", "type", "direction", "action", "result", "to", "from", "recording", "extension", "transport", "lastModifiedTime", "billing", "legs"}, {"uri", "id", "sessionId", "startTime", "duration", "type", "direction", "action", "result", "to", "from", "recording", "extension", "transport", "lastModifiedTime", "billing", "legs"}),
    #"Expanded to" = Table.ExpandRecordColumn(#"Expanded Column1", "to", {"phoneNumber", "location"}, {"phoneNumber", "location"}),
    #"Expanded from" = Table.ExpandRecordColumn(#"Expanded to", "from", {"phoneNumber", "name", "device"}, {"phoneNumber.1", "name", "device"}),
    #"Expanded device" = Table.ExpandRecordColumn(#"Expanded from", "device", {"id"}, {"id.1"}),
    #"Expanded extension" = Table.ExpandRecordColumn(#"Expanded device", "extension", {"id"}, {"id.2"}),
    #"Removed Columns" = Table.RemoveColumns(#"Expanded extension",{"billing", "legs", "uri", "id", "sessionId", "recording"}),
    #"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"startTime", "Call Start Time"}, {"duration", "Call Duration"}, {"type", "Call Type"}, {"direction", "Call Direction"}, {"action", "Type of Call"}, {"result", "Call Results"}, {"phoneNumber", "Outbound Phone Number"}, {"location", "Location of Call"}}),
    #"Removed Columns1" = Table.RemoveColumns(#"Renamed Columns",{"phoneNumber.1"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Removed Columns1",{{"name", "Sales Rep"}, {"id.1", "Sales Rep Ext ID"}}),
    #"Removed Columns2" = Table.RemoveColumns(#"Renamed Columns1",{"id.2"})
in
    #"Removed Columns2"